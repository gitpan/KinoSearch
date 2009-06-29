#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/IndexManager.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/IndexFileNames.h"
#include "KinoSearch/Util/StringHelper.h"

IndexManager*
IxManager_new(Folder *folder)
{
    IndexManager *self = (IndexManager*)VTable_Make_Obj(&INDEXMANAGER);
    return IxManager_init(self, folder);
}

IndexManager*
IxManager_init(IndexManager *self, Folder *folder)
{
    self->folder = (Folder*)INCREF(folder);
    return self;
}

void
IxManager_destroy(IndexManager *self)
{
    DECREF(self->folder);
    FREE_OBJ(self);
}

static void
S_cat_seg_name(CharBuf *seg_name, u32_t seg_num)
{
    CharBuf *base_36 = StrHelp_to_base36(seg_num);
    CB_Cat_Str(seg_name, "seg_", 4);
    CB_Cat(seg_name, base_36);
    DECREF(base_36);
}

Segment*
IxManager_make_new_segment(IndexManager *self, Snapshot *snapshot)
{
    VArray *files = Snapshot_List(snapshot);
    u32_t i, max;
    i32_t highest_seg_num = 0;
    CharBuf *seg_name = CB_new(20);
    Segment *segment;

    /* Find highest seg num. */
    for (i = 0, max = VA_Get_Size(files); i < max; i++) {
        CharBuf *file = (CharBuf*)VA_Fetch(files, i);
        if (CB_Starts_With_Str(file, "seg_", 4)) {
            i32_t seg_num = IxFileNames_extract_gen(file);
            if (seg_num > highest_seg_num) { highest_seg_num = seg_num; }
        }
    }

    /* Create segment with num one greater than current max. */
    S_cat_seg_name(seg_name, highest_seg_num + 1);
    segment = Seg_new(seg_name, self->folder);

    DECREF(seg_name);
    DECREF(files);

    return segment;
}

CharBuf*
IxManager_make_snapshot_filename(IndexManager *self)
{
    VArray *files = Folder_List(self->folder);
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

VArray*
IxManager_segreaders_to_merge(IndexManager *self, PolyReader *reader, 
                              bool_t all)
{
    VArray *seg_readers = VA_Shallow_Copy(PolyReader_Get_Seg_Readers(reader));
    UNUSED_VAR(self);

    if (!all) { 
        u32_t i;
        u32_t total_docs = 0;
        u32_t threshold = 0;
        const u32_t num_seg_readers = VA_Get_Size(seg_readers);

        /* Sort by ascending size in docs. */
        VA_Sort(seg_readers, S_compare_doc_count, NULL);

        /* Find sparsely populated segments. */
        for (i = 0; i < num_seg_readers; i++) {
            SegReader *seg_reader = (SegReader*)VA_Fetch(seg_readers, i);
            total_docs += SegReader_Doc_Count(seg_reader);
            if (total_docs < Math_fibonacci(i + 5)) {
                threshold = i + 1;
            }
        }
        VA_Splice(seg_readers, threshold, num_seg_readers);
    }

    return seg_readers;
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

