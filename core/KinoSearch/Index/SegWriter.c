#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SegWriter.h"
#include "KinoSearch/Architecture.h"
#include "KinoSearch/Doc.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Index/DeletionsWriter.h"
#include "KinoSearch/Index/Inverter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/PostingsWriter.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Util/I32Array.h"

SegWriter*
SegWriter_new(Schema *schema, Snapshot *snapshot, Segment *segment,
              PolyReader *polyreader)
{
    SegWriter *self = (SegWriter*)VTable_Make_Obj(&SEGWRITER);
    return SegWriter_init(self, schema, snapshot, segment, polyreader);
}

SegWriter*
SegWriter_init(SegWriter *self, Schema *schema, Snapshot *snapshot,
               Segment *segment, PolyReader *polyreader)
{
    Architecture *arch   = Schema_Get_Architecture(schema);
    DataWriter_init((DataWriter*)self, schema, snapshot, segment, polyreader);
    self->by_api   = Hash_new(0);
    self->inverter = Inverter_new(schema, segment);
    self->writers  = VA_new(16);
    Arch_Init_Seg_Writer(arch, self);
    return self;
}

void
SegWriter_destroy(SegWriter *self) 
{
    DECREF(self->inverter);
    DECREF(self->writers);
    DECREF(self->by_api);
    DECREF(self->del_writer);
    SUPER_DESTROY(self, SEGWRITER);
}

void
SegWriter_register(SegWriter *self, const CharBuf *api, DataWriter *component)
{
    ASSERT_IS_A(component, DATAWRITER);
    if (Hash_Fetch(self->by_api, (Obj*)api)) {
        THROW("API %o already registered", api);
    }
    Hash_Store(self->by_api, (Obj*)api, (Obj*)component);
}

Obj*
SegWriter_fetch(SegWriter *self, const CharBuf *api)
{
    return Hash_Fetch(self->by_api, (Obj*)api);
}

void
SegWriter_add_writer(SegWriter *self, DataWriter *writer)
{
    VA_Push(self->writers, (Obj*)writer);
}

void
SegWriter_prep_seg_dir(SegWriter *self)
{
    Folder  *folder   = PolyReader_Get_Folder(self->polyreader);
    CharBuf *seg_name = Seg_Get_Name(self->segment);
    VArray  *files    = Folder_List(folder);
    u32_t    i, max;

    /* Create the segment directory. */
    if (!Folder_Exists(folder, seg_name)) {
        Folder_MkDir(folder, seg_name);
    }

    /* Clear stale segment files from crashed indexing sessions. */
    for (i = 0, max = VA_Get_Size(files); i < max; i++) {
        CharBuf *filename = (CharBuf*)VA_Fetch(files, i);
        if (   CB_Starts_With(filename, seg_name) 
            && !CB_Equals(filename, (Obj*)seg_name)
        ) {
            if (!Folder_Delete(folder, filename)) {
                CharBuf *mess = MAKE_MESS("Can't delete '%o'", filename);
                DECREF(files);
                Err_throw_mess(mess);
            }
        }
    }
    DECREF(files);
}

void
SegWriter_add_doc(SegWriter *self, Doc *doc, float boost)
{
    i32_t doc_id = Seg_Increment_Count(self->segment, 1);
    Inverter_Invert_Doc(self->inverter, doc);
    Inverter_Set_Boost(self->inverter, boost);
    SegWriter_Add_Inverted_Doc(self, self->inverter, doc_id);
}

void
SegWriter_add_inverted_doc(SegWriter *self, Inverter *inverter, i32_t doc_id)
{
    u32_t i, max;
    for (i = 0, max = VA_Get_Size(self->writers); i < max; i++) {
        DataWriter *writer = (DataWriter*)VA_Fetch(self->writers, i);
        DataWriter_Add_Inverted_Doc(writer, inverter, doc_id);
    }
}

/* Adjust current doc id. We create our own doc_count rather than rely on
 * SegReader's number because the DeletionsWriter and the SegReader are
 * probably out of sync. */
static void
S_adjust_doc_id(SegWriter *self, SegReader *reader, I32Array *doc_map)
{
    u32_t doc_count = SegReader_Doc_Max(reader);
    u32_t i, max;
    for (i = 1, max = I32Arr_Get_Size(doc_map); i < max; i++) {
        if (I32Arr_Get(doc_map, i) == 0) doc_count--;
    }
    Seg_Increment_Count(self->segment, doc_count);
}

void
SegWriter_add_segment(SegWriter *self, SegReader *reader, I32Array *doc_map)
{
    u32_t i, max;

    /* Bulk add the slab of documents to the various writers. */
    for (i = 0, max = VA_Get_Size(self->writers); i < max; i++) {
        DataWriter *writer = (DataWriter*)VA_Fetch(self->writers, i);
        DataWriter_Add_Segment(writer, reader, doc_map);
    }

    /* Bulk add the segment to the DeletionsWriter, so that it can merge
     * previous segment files as necessary. */
    DelWriter_Add_Segment(self->del_writer, reader, doc_map);

    /* Adust the document id. */
    S_adjust_doc_id(self, reader, doc_map);
}

void
SegWriter_merge_segment(SegWriter *self, SegReader *reader, I32Array *doc_map)
{
    Snapshot *snapshot = SegWriter_Get_Snapshot(self);
    CharBuf  *seg_name = Seg_Get_Name(SegReader_Get_Segment(reader));
    CharBuf  *segmeta_file = CB_newf("%o/segmeta.json", seg_name);
    u32_t i, max;

    /* Have all the sub-writers merge the segment. */
    for (i = 0, max = VA_Get_Size(self->writers); i < max; i++) {
        DataWriter *writer = (DataWriter*)VA_Fetch(self->writers, i);
        DataWriter_Merge_Segment(writer, reader, doc_map);
    }
    DelWriter_Merge_Segment(self->del_writer, reader, doc_map);

    /* Remove seg directory and segmeta entries from snapshot. */
    Snapshot_Delete_Entry(snapshot, seg_name);
    Snapshot_Delete_Entry(snapshot, segmeta_file);
    DECREF(segmeta_file);

    /* Adust the document id. */
    S_adjust_doc_id(self, reader, doc_map);
}

void
SegWriter_delete_segment(SegWriter *self, SegReader *reader)
{
    Snapshot *snapshot = SegWriter_Get_Snapshot(self);
    CharBuf  *seg_name = Seg_Get_Name(SegReader_Get_Segment(reader));
    CharBuf  *segmeta_file = CB_newf("%o/segmeta.json", seg_name);
    u32_t i, max;

    /* Have all the sub-writers delete the segment. */
    for (i = 0, max = VA_Get_Size(self->writers); i < max; i++) {
        DataWriter *writer = (DataWriter*)VA_Fetch(self->writers, i);
        DataWriter_Delete_Segment(writer, reader);
    }
    DelWriter_Delete_Segment(self->del_writer, reader);

    /* Remove seg directory and segmeta entries from snapshot. */
    Snapshot_Delete_Entry(snapshot, seg_name);
    Snapshot_Delete_Entry(snapshot, segmeta_file);
    DECREF(segmeta_file);
}

void
SegWriter_finish(SegWriter *self)
{
    u32_t i, max;

    /* Finish off children. */
    for (i = 0, max = VA_Get_Size(self->writers); i < max; i++) {
        DataWriter *writer = (DataWriter*)VA_Fetch(self->writers, i);
        DataWriter_Finish(writer);
    }


    /* Write segment metadata. Add segment directory and segment file to
     * snapshot. */
    {
        Snapshot *snapshot = SegWriter_Get_Snapshot(self);
        CharBuf *seg_name  = Seg_Get_Name(self->segment);
        CharBuf *segmeta_filename = CB_newf("%o/segmeta.json", seg_name);
        Seg_Write_File(self->segment);
        Snapshot_Add_Entry(snapshot, seg_name);
        Snapshot_Add_Entry(snapshot, segmeta_filename);
        DECREF(segmeta_filename);
    }
}

void
SegWriter_add_data_writer(SegWriter *self, DataWriter *writer)
{
    VA_Push(self->writers, (Obj*)writer);
}

void
SegWriter_set_del_writer(SegWriter *self, DeletionsWriter *del_writer)
{
    DECREF(self->del_writer);
    self->del_writer = del_writer
                     ? (DeletionsWriter*)INCREF(del_writer)
                     : NULL;
}

DeletionsWriter*
SegWriter_get_del_writer(SegWriter *self) { return self->del_writer; }

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

