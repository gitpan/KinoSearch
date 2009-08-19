#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/IndexManager.h"
#include "KinoSearch/Index/DeletionsWriter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/Lock.h"
#include "KinoSearch/Store/LockFactory.h"
#include "KinoSearch/Util/IndexFileNames.h"
#include "KinoSearch/Util/Json.h"
#include "KinoSearch/Util/StringHelper.h"

IndexManager*
IxManager_new(const CharBuf *hostname, LockFactory *lock_factory)
{
    IndexManager *self = (IndexManager*)VTable_Make_Obj(INDEXMANAGER);
    return IxManager_init(self, hostname, lock_factory);
}

IndexManager*
IxManager_init(IndexManager *self, const CharBuf *hostname, 
               LockFactory *lock_factory)
{
    self->hostname            = hostname 
                              ? CB_Clone(hostname) 
                              : CB_new_from_trusted_utf8("", 0);
    self->lock_factory        = lock_factory 
                              ? (LockFactory*)INCREF(lock_factory) 
                              : NULL;
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
    DECREF(self->hostname);
    DECREF(self->folder);
    DECREF(self->lock_factory);
    SUPER_DESTROY(self, INDEXMANAGER);
}

i32_t
IxManager_highest_seg_num(IndexManager *self, Snapshot *snapshot)
{
    VArray *files = Snapshot_List(snapshot);
    u32_t i, max;
    i32_t highest_seg_num = 0;
    UNUSED_VAR(self);
    for (i = 0, max = VA_Get_Size(files); i < max; i++) {
        CharBuf *file = (CharBuf*)VA_Fetch(files, i);
        if (CB_Ends_With_Str(file, "segmeta.json", 12)) {
            i32_t seg_num = IxFileNames_extract_gen(file);
            if (seg_num > highest_seg_num) { highest_seg_num = seg_num; }
        }
    }
    DECREF(files);
    return highest_seg_num;
}

CharBuf*
IxManager_make_snapshot_filename(IndexManager *self)
{
    Folder *folder = (Folder*)ASSERT_IS_A(self->folder, FOLDER);
    VArray *files = Folder_List(folder);
    u32_t i, max;
    i32_t max_gen = 0;

    for (i = 0, max = VA_Get_Size(files); i < max; i++) {
        CharBuf *file = (CharBuf*)VA_Fetch(files, i);
        if (    CB_Starts_With_Str(file, "snapshot_", 9)
            && CB_Ends_With_Str(file, ".json", 5)
        ) {
            i32_t gen = IxFileNames_extract_gen(file);
            if (gen > max_gen) { max_gen = gen; }
        }
    }
    DECREF(files);

    {
        i32_t    new_gen = max_gen + 1;
        CharBuf *base_36 = StrHelp_to_base36(new_gen);
        CharBuf *snapfile = CB_newf("snapshot_%o.json", base_36);
        DECREF(base_36);
        return snapfile;
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
S_check_cutoff(VArray *array, u32_t tick, void *data)
{
    SegReader *seg_reader = (SegReader*)VA_Fetch(array, tick);
    i32_t cutoff = *(i32_t*)data;
    return SegReader_Get_Seg_Num(seg_reader) > cutoff;
}

static u32_t
S_fibonacci(u32_t n) {
    u32_t result = 0;
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
                  DeletionsWriter *del_writer, i32_t cutoff, bool_t optimize)
{
    VArray *seg_readers = PolyReader_Get_Seg_Readers(reader);
    VArray *recyclables = VA_Grep(seg_readers, S_check_cutoff, &cutoff);
    u32_t i;
    u32_t total_docs = 0;
    u32_t threshold = 0;
    const u32_t num_seg_readers = VA_Get_Size(recyclables);
    UNUSED_VAR(self);

    if (optimize) { return recyclables; }

    /* Sort by ascending size in docs. */
    VA_Sort(recyclables, S_compare_doc_count, NULL);

    /* Find sparsely populated segments. */
    for (i = 0; i < num_seg_readers; i++) {
        u32_t num_segs_when_done = num_seg_readers - threshold + 1;
        SegReader *seg_reader = (SegReader*)VA_Fetch(recyclables, i);
        total_docs += SegReader_Doc_Count(seg_reader);
        if (total_docs < S_fibonacci(num_segs_when_done + 5)) {
            threshold = i + 1;
        }
    }
    VA_Splice(recyclables, threshold, num_seg_readers);

    /* Find segments where at least 10% of all docs have been deleted. */
    for (i = threshold + 1; i < num_seg_readers; i++) {
        SegReader *seg_reader = (SegReader*)VA_Fetch(seg_readers, i);
        CharBuf   *seg_name   = SegReader_Get_Seg_Name(seg_reader);
        double doc_max = SegReader_Doc_Max(seg_reader);
        double num_deletions = DelWriter_Seg_Del_Count(del_writer, seg_name);
        double del_proportion = num_deletions / doc_max;
        if (del_proportion >= 0.1) {
            VA_Push(recyclables, INCREF(seg_reader));
        }
    }

    return recyclables;
}

static LockFactory*
S_obtain_lock_factory(IndexManager *self)
{
    if (!self->lock_factory) {
        if (!self->folder) { 
            THROW(ERR, "Can't create a LockFactory without a Folder");
        }
        self->lock_factory = LockFact_new(self->folder, self->hostname);
    }
    return self->lock_factory;
}

Lock*
IxManager_make_write_lock(IndexManager *self)
{
    static ZombieCharBuf write_lock_name = ZCB_LITERAL("write");
    LockFactory *lock_factory = S_obtain_lock_factory(self);
    return LockFact_Make_Lock(lock_factory, (CharBuf*)&write_lock_name,
        self->write_lock_timeout, self->write_lock_interval);
}

Lock*
IxManager_make_deletion_lock(IndexManager *self)
{
    static ZombieCharBuf lock_name = ZCB_LITERAL("deletion");
    LockFactory *lock_factory = S_obtain_lock_factory(self);
    return LockFact_Make_Lock(lock_factory, (CharBuf*)&lock_name, 
        self->deletion_lock_timeout, self->deletion_lock_interval);
}

Lock*
IxManager_make_merge_lock(IndexManager *self)
{
    static ZombieCharBuf merge_lock_name = ZCB_LITERAL("merge");
    LockFactory *lock_factory = S_obtain_lock_factory(self);
    return LockFact_Make_Lock(lock_factory, (CharBuf*)&merge_lock_name,
        self->merge_lock_timeout, self->merge_lock_interval);
}

void
IxManager_write_merge_data(IndexManager *self, i32_t cutoff)
{
    static ZombieCharBuf merge_json = ZCB_LITERAL("merge.json");
    Hash *data = Hash_new(1);
    bool_t success;
    Hash_Store_Str(data, "cutoff", 6, (Obj*)CB_newf("%i32", cutoff));
    success = Json_spew_json((Obj*)data, self->folder, (CharBuf*)&merge_json);
    DECREF(data);
    if (!success) {
        THROW(ERR, "Failed to write to %o", &merge_json);
    }
}

Hash*
IxManager_read_merge_data(IndexManager *self)
{
    static ZombieCharBuf merge_json = ZCB_LITERAL("merge.json");
    if (Folder_Exists(self->folder, (CharBuf*)&merge_json)) {
        Hash *stuff 
            = (Hash*)Json_slurp_json(self->folder, (CharBuf*)&merge_json);
        if (stuff) {
            ASSERT_IS_A(stuff, HASH);
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
    static ZombieCharBuf merge_json = ZCB_LITERAL("merge.json");
    return Folder_Delete(self->folder, (CharBuf*)&merge_json) != 0;
}

Lock*
IxManager_make_snapshot_read_lock(IndexManager *self, const CharBuf *filename)
{
    ZombieCharBuf lock_name = ZCB_make(filename);
    LockFactory *lock_factory = S_obtain_lock_factory(self);
    
    if (   !CB_Starts_With_Str(filename, "snapshot_", 9)
        || !CB_Ends_With_Str(filename, ".json", 5)
    ) {
        THROW(ERR, "Not a snapshot filename: %o", filename);
    }
        
    /* Truncate ".json" from end of snapshot file name. */
    ZCB_Chop(&lock_name, sizeof(".json") - 1);

    return LockFact_Make_Shared_Lock(lock_factory, (CharBuf*)&lock_name, 1000, 100);
}

void
IxManager_set_folder(IndexManager *self, Folder *folder)
{
    DECREF(self->folder);
    self->folder = folder ? (Folder*)INCREF(folder) : NULL;
}

Folder*
IxManager_get_folder(IndexManager *self)   
    { return self->folder; }

CharBuf*
IxManager_get_hostname(IndexManager *self) 
    { return self->hostname; }
u32_t
IxManager_get_write_lock_timeout(IndexManager *self) 
    { return self->write_lock_timeout; }
u32_t
IxManager_get_write_lock_interval(IndexManager *self) 
    { return self->write_lock_interval; }
u32_t
IxManager_get_merge_lock_timeout(IndexManager *self) 
    { return self->merge_lock_timeout; }
u32_t
IxManager_get_merge_lock_interval(IndexManager *self) 
    { return self->merge_lock_interval; }
u32_t
IxManager_get_deletion_lock_timeout(IndexManager *self) 
    { return self->deletion_lock_timeout; }
u32_t
IxManager_get_deletion_lock_interval(IndexManager *self) 
    { return self->deletion_lock_interval; }

void
IxManager_set_write_lock_timeout(IndexManager *self, u32_t timeout)
    { self->write_lock_timeout = timeout; }
void
IxManager_set_write_lock_interval(IndexManager *self, u32_t interval)
    { self->write_lock_interval = interval; }
void
IxManager_set_merge_lock_timeout(IndexManager *self, u32_t timeout)
    { self->merge_lock_timeout = timeout; }
void
IxManager_set_merge_lock_interval(IndexManager *self, u32_t interval)
    { self->merge_lock_interval = interval; }
void
IxManager_set_deletion_lock_timeout(IndexManager *self, u32_t timeout)
    { self->deletion_lock_timeout = timeout; }
void
IxManager_set_deletion_lock_interval(IndexManager *self, u32_t interval)
    { self->deletion_lock_interval = interval; }

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

