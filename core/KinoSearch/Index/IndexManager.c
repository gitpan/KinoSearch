#define C_KINO_INDEXMANAGER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/IndexManager.h"
#include "KinoSearch/Index/DeletionsWriter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Store/DirHandle.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/Lock.h"
#include "KinoSearch/Store/LockFactory.h"
#include "KinoSearch/Util/IndexFileNames.h"
#include "KinoSearch/Util/Json.h"
#include "KinoSearch/Util/StringHelper.h"

IndexManager*
IxManager_new(const CharBuf *host, LockFactory *lock_factory)
{
    IndexManager *self = (IndexManager*)VTable_Make_Obj(INDEXMANAGER);
    return IxManager_init(self, host, lock_factory);
}

IndexManager*
IxManager_init(IndexManager *self, const CharBuf *host, 
               LockFactory *lock_factory)
{
    self->host                = host 
                              ? CB_Clone(host) 
                              : CB_new_from_trusted_utf8("", 0);
    self->lock_factory        = (LockFactory*)INCREF(lock_factory);
    self->folder              = NULL;
    self->write_lock_timeout  = 1000;
    self->write_lock_interval = 100;
    self->merge_lock_timeout  = 0;
    self->merge_lock_interval = 1000;
    self->deletion_lock_timeout  = 1000;
    self->deletion_lock_interval = 100;

    return self;
}

void
IxManager_destroy(IndexManager *self)
{
    DECREF(self->host);
    DECREF(self->folder);
    DECREF(self->lock_factory);
    SUPER_DESTROY(self, INDEXMANAGER);
}

int64_t
IxManager_highest_seg_num(IndexManager *self, Snapshot *snapshot)
{
    VArray *files = Snapshot_List(snapshot);
    uint32_t i, max;
    uint64_t highest_seg_num = 0;
    UNUSED_VAR(self);
    for (i = 0, max = VA_Get_Size(files); i < max; i++) {
        CharBuf *file = (CharBuf*)VA_Fetch(files, i);
        if (Seg_valid_seg_name(file)) {
            uint64_t seg_num = IxFileNames_extract_gen(file);
            if (seg_num > highest_seg_num) { highest_seg_num = seg_num; }
        }
    }
    DECREF(files);
    return (int64_t)highest_seg_num;
}

CharBuf*
IxManager_make_snapshot_filename(IndexManager *self)
{
    Folder *folder = (Folder*)CERTIFY(self->folder, FOLDER);
    DirHandle *dh = Folder_Open_Dir(folder, NULL);
    CharBuf *entry;
    uint64_t max_gen = 0;

    if (!dh) { RETHROW(INCREF(Err_get_error())); }
    entry = DH_Get_Entry(dh);
    while (DH_Next(dh)) {
        if (    CB_Starts_With_Str(entry, "snapshot_", 9)
            && CB_Ends_With_Str(entry, ".json", 5)
        ) {
            uint64_t gen = IxFileNames_extract_gen(entry);
            if (gen > max_gen) { max_gen = gen; }
        }
    }
    DECREF(dh);

    {
        uint64_t new_gen = max_gen + 1;
        char  base36[StrHelp_MAX_BASE36_BYTES];
        StrHelp_to_base36(new_gen, &base36);
        return CB_newf("snapshot_%s.json", &base36);
    }
}

static int
S_compare_doc_count(void *context, const void *va, const void *vb)
{
    SegReader *a = *(SegReader**)va;
    SegReader *b = *(SegReader**)vb;
    UNUSED_VAR(context);
    return SegReader_Doc_Count(a) - SegReader_Doc_Count(b);
}

static bool_t
S_check_cutoff(VArray *array, uint32_t tick, void *data)
{
    SegReader *seg_reader = (SegReader*)VA_Fetch(array, tick);
    int64_t cutoff = *(int64_t*)data;
    return SegReader_Get_Seg_Num(seg_reader) > cutoff;
}

static uint32_t
S_fibonacci(uint32_t n) {
    uint32_t result = 0;
    if (n > 46) {
        THROW(ERR, "input %u32 too high", n); 
    }   
    else if (n < 2) {
        result = n;
    }   
    else {
        result = S_fibonacci(n - 1) + S_fibonacci(n - 2); 
    }   
    return result;
}

VArray*
IxManager_recycle(IndexManager *self, PolyReader *reader, 
                  DeletionsWriter *del_writer, int64_t cutoff, bool_t optimize)
{
    VArray *seg_readers = PolyReader_Get_Seg_Readers(reader);
    VArray *candidates  = VA_Gather(seg_readers, S_check_cutoff, &cutoff);
    VArray *recyclables = VA_new(VA_Get_Size(candidates));
    uint32_t i;
    uint32_t total_docs = 0;
    uint32_t threshold = 0;
    const uint32_t num_candidates = VA_Get_Size(candidates);
    UNUSED_VAR(self);

    if (optimize) { 
        DECREF(recyclables);
        return candidates; 
    }

    // Sort by ascending size in docs. 
    VA_Sort(candidates, S_compare_doc_count, NULL);

    // Find sparsely populated segments. 
    for (i = 0; i < num_candidates; i++) {
        uint32_t num_segs_when_done = num_candidates - threshold + 1;
        SegReader *seg_reader = (SegReader*)VA_Fetch(candidates, i);
        total_docs += SegReader_Doc_Count(seg_reader);
        if (total_docs < S_fibonacci(num_segs_when_done + 5)) {
            threshold = i + 1;
        }
    }

    // If recycling, always merge at least two segments so that we don't get
    // stuck merging the same big segment over and over on small commits.
    if (threshold == 1 && num_candidates > 2) {
        threshold = 2;
    }

    // Move SegReaders to be recycled.
    for (i = 0; i < threshold; i++) {
        VA_Store(recyclables, i, VA_Delete(candidates, i));
    }

    // Find segments where at least 10% of all docs have been deleted. 
    for (i = threshold; i < num_candidates; i++) {
        SegReader *seg_reader = (SegReader*)VA_Delete(candidates, i);
        CharBuf   *seg_name   = SegReader_Get_Seg_Name(seg_reader);
        double doc_max = SegReader_Doc_Max(seg_reader);
        double num_deletions = DelWriter_Seg_Del_Count(del_writer, seg_name);
        double del_proportion = num_deletions / doc_max;
        if (del_proportion >= 0.1) {
            VA_Push(recyclables, (Obj*)seg_reader);
        }
        else {
            DECREF(seg_reader);
        }
    }

    DECREF(candidates);
    return recyclables;
}

static LockFactory*
S_obtain_lock_factory(IndexManager *self)
{
    if (!self->lock_factory) {
        if (!self->folder) { 
            THROW(ERR, "Can't create a LockFactory without a Folder");
        }
        self->lock_factory = LockFact_new(self->folder, self->host);
    }
    return self->lock_factory;
}

Lock*
IxManager_make_write_lock(IndexManager *self)
{
    ZombieCharBuf *write_lock_name = ZCB_WRAP_STR("write", 5);
    LockFactory *lock_factory = S_obtain_lock_factory(self);
    return LockFact_Make_Lock(lock_factory, (CharBuf*)write_lock_name,
        self->write_lock_timeout, self->write_lock_interval);
}

Lock*
IxManager_make_deletion_lock(IndexManager *self)
{
    ZombieCharBuf *lock_name = ZCB_WRAP_STR("deletion", 8);
    LockFactory *lock_factory = S_obtain_lock_factory(self);
    return LockFact_Make_Lock(lock_factory, (CharBuf*)lock_name, 
        self->deletion_lock_timeout, self->deletion_lock_interval);
}

Lock*
IxManager_make_merge_lock(IndexManager *self)
{
    ZombieCharBuf *merge_lock_name = ZCB_WRAP_STR("merge", 5);
    LockFactory *lock_factory = S_obtain_lock_factory(self);
    return LockFact_Make_Lock(lock_factory, (CharBuf*)merge_lock_name,
        self->merge_lock_timeout, self->merge_lock_interval);
}

void
IxManager_write_merge_data(IndexManager *self, int64_t cutoff)
{
    ZombieCharBuf *merge_json = ZCB_WRAP_STR("merge.json", 10);
    Hash *data = Hash_new(1);
    bool_t success;
    Hash_Store_Str(data, "cutoff", 6, (Obj*)CB_newf("%i64", cutoff));
    success = Json_spew_json((Obj*)data, self->folder, (CharBuf*)merge_json);
    DECREF(data);
    if (!success) {
        THROW(ERR, "Failed to write to %o", &merge_json);
    }
}

Hash*
IxManager_read_merge_data(IndexManager *self)
{
    ZombieCharBuf *merge_json = ZCB_WRAP_STR("merge.json", 10);
    if (Folder_Exists(self->folder, (CharBuf*)merge_json)) {
        Hash *stuff 
            = (Hash*)Json_slurp_json(self->folder, (CharBuf*)merge_json);
        if (stuff) {
            CERTIFY(stuff, HASH);
            return stuff;
        }
        else {
            return Hash_new(0);
        }
    }
    else {
        return NULL;
    }
}

bool_t
IxManager_remove_merge_data(IndexManager *self)
{
    ZombieCharBuf *merge_json = ZCB_WRAP_STR("merge.json", 10);
    return Folder_Delete(self->folder, (CharBuf*)merge_json) != 0;
}

Lock*
IxManager_make_snapshot_read_lock(IndexManager *self, const CharBuf *filename)
{
    ZombieCharBuf *lock_name = ZCB_WRAP(filename);
    LockFactory *lock_factory = S_obtain_lock_factory(self);
    
    if (   !CB_Starts_With_Str(filename, "snapshot_", 9)
        || !CB_Ends_With_Str(filename, ".json", 5)
    ) {
        THROW(ERR, "Not a snapshot filename: %o", filename);
    }
        
    // Truncate ".json" from end of snapshot file name. 
    ZCB_Chop(lock_name, sizeof(".json") - 1);

    return LockFact_Make_Shared_Lock(lock_factory, (CharBuf*)lock_name, 1000, 100);
}

void
IxManager_set_folder(IndexManager *self, Folder *folder)
{
    DECREF(self->folder);
    self->folder = (Folder*)INCREF(folder);
}

Folder*
IxManager_get_folder(IndexManager *self)   
    { return self->folder; }

CharBuf*
IxManager_get_host(IndexManager *self) 
    { return self->host; }
uint32_t
IxManager_get_write_lock_timeout(IndexManager *self) 
    { return self->write_lock_timeout; }
uint32_t
IxManager_get_write_lock_interval(IndexManager *self) 
    { return self->write_lock_interval; }
uint32_t
IxManager_get_merge_lock_timeout(IndexManager *self) 
    { return self->merge_lock_timeout; }
uint32_t
IxManager_get_merge_lock_interval(IndexManager *self) 
    { return self->merge_lock_interval; }
uint32_t
IxManager_get_deletion_lock_timeout(IndexManager *self) 
    { return self->deletion_lock_timeout; }
uint32_t
IxManager_get_deletion_lock_interval(IndexManager *self) 
    { return self->deletion_lock_interval; }

void
IxManager_set_write_lock_timeout(IndexManager *self, uint32_t timeout)
    { self->write_lock_timeout = timeout; }
void
IxManager_set_write_lock_interval(IndexManager *self, uint32_t interval)
    { self->write_lock_interval = interval; }
void
IxManager_set_merge_lock_timeout(IndexManager *self, uint32_t timeout)
    { self->merge_lock_timeout = timeout; }
void
IxManager_set_merge_lock_interval(IndexManager *self, uint32_t interval)
    { self->merge_lock_interval = interval; }
void
IxManager_set_deletion_lock_timeout(IndexManager *self, uint32_t timeout)
    { self->deletion_lock_timeout = timeout; }
void
IxManager_set_deletion_lock_interval(IndexManager *self, uint32_t interval)
    { self->deletion_lock_interval = interval; }

/* Copyright 2007-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

