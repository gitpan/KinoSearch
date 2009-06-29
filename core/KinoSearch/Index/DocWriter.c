#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/DocWriter.h"
#include "KinoSearch/Doc.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/DocReader.h"
#include "KinoSearch/Index/Inverter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/ByteBuf.h"
#include "KinoSearch/Util/Host.h"
#include "KinoSearch/Util/I32Array.h"

static OutStream*
S_lazy_init(DocWriter *self);

i32_t DocWriter_current_file_format = 2;

DocWriter*
DocWriter_new(Schema *schema, Snapshot *snapshot, Segment *segment, 
              PolyReader *polyreader)
{
    DocWriter *self = (DocWriter*)VTable_Make_Obj(&DOCWRITER);
    return DocWriter_init(self, schema, snapshot, segment, polyreader);
}

DocWriter*
DocWriter_init(DocWriter *self, Schema *schema, Snapshot *snapshot,
               Segment *segment, PolyReader *polyreader)
{
    DataWriter_init((DataWriter*)self, schema, snapshot, segment, polyreader);
    return self;
}

void
DocWriter_destroy(DocWriter *self)
{
    DECREF(self->dat_out);
    DECREF(self->ix_out);
    SUPER_DESTROY(self, DOCWRITER);
}

static OutStream*
S_lazy_init(DocWriter *self) 
{
    if (!self->dat_out) {
        Snapshot *snapshot  = DocWriter_Get_Snapshot(self);
        Folder   *folder    = self->folder;
        CharBuf  *seg_name  = Seg_Get_Name(self->segment);
        CharBuf  *ix_file   = CB_newf("%o/documents.ix", seg_name);
        CharBuf  *dat_file  = CB_newf("%o/documents.dat", seg_name);

        /* Get streams. */
        Snapshot_Add_Entry(snapshot, ix_file);
        Snapshot_Add_Entry(snapshot, dat_file);
        self->ix_out  = Folder_Open_Out(folder, ix_file);
        self->dat_out = Folder_Open_Out(folder, dat_file);
        if (!self->ix_out)  { THROW("Can't open %o", ix_file); }
        if (!self->dat_out) { THROW("Can't open %o", dat_file); }
        DECREF(ix_file);
        DECREF(dat_file);

        /* Go past non-doc #0. */
        OutStream_Write_U64(self->ix_out, 0);
    }

    return self->dat_out;
}

void
DocWriter_add_inverted_doc(DocWriter *self, Inverter *inverter, 
                           i32_t doc_id)
{
    OutStream *dat_out         = S_lazy_init(self);
    OutStream *ix_out          = self->ix_out;
    u32_t      num_stored      = 0;
    u64_t      start           = OutStream_Tell(dat_out);
    i64_t      expected        = OutStream_Tell(ix_out) / 8;

    /* Verify doc id. */
    if (doc_id != expected)
        THROW("Expected doc id %i64 but got %i32", expected, doc_id);

    /* Write the number of stored fields. */
    Inverter_Iter_Init(inverter);
    while (Inverter_Next(inverter)) {
        FieldType *type = Inverter_Get_Type(inverter);
        if (type->stored) num_stored++;
    }
    OutStream_Write_C32(dat_out, num_stored);

    Inverter_Iter_Init(inverter);
    while (Inverter_Next(inverter)) {
        /* Only store fields marked as "stored". */
        FieldType *type = Inverter_Get_Type(inverter);
        if (type->stored) {
            CharBuf *field = Inverter_Get_Field_Name(inverter);
            Obj *value = Inverter_Get_Value(inverter);
            CB_Serialize(field, dat_out);
            Obj_Serialize(value, dat_out);
        }
    }

    /* Write file pointer. */
    OutStream_Write_U64(ix_out, start);
}

void
DocWriter_add_segment(DocWriter *self, SegReader *reader, 
                      I32Array *doc_map)
{
    i32_t doc_max = SegReader_Doc_Max(reader);

    if (doc_max == 0) {
        /* Bail if the supplied segment is empty. */
        return;
    }
    else {
        OutStream     *const dat_out    = S_lazy_init(self);
        OutStream     *const ix_out     = self->ix_out;
        ByteBuf       *const buffer     = BB_new(0);
        DefaultDocReader *const doc_reader = (DefaultDocReader*)ASSERT_IS_A(
            SegReader_Obtain(reader, DOCREADER.name), DEFAULTDOCREADER);
        i32_t i, max;

        for (i = 1, max = SegReader_Doc_Max(reader); i <= max; i++) {
            if (I32Arr_Get(doc_map, i)) {
                u64_t start = OutStream_Tell(dat_out);
                size_t size;

                /* Copy record over. */ 
                DefDocReader_Read_Record(doc_reader, buffer, i);
                size = BB_Get_Size(buffer);
                OutStream_Write_Bytes(dat_out, buffer->ptr, size);

                /* Write file pointer. */
                OutStream_Write_U64(ix_out, start);
            }
        }

        DECREF(buffer);
    }
}

void
DocWriter_delete_segment(DocWriter *self, SegReader *reader)
{
    CharBuf  *merged_seg_name = Seg_Get_Name(SegReader_Get_Segment(reader));
    Snapshot *snapshot = DocWriter_Get_Snapshot(self);
    CharBuf  *file     = CB_newf("%o/documents.ix", merged_seg_name);
    Snapshot_Delete_Entry(snapshot, file);
    CB_setf(file, "%o/documents.dat", merged_seg_name);
    Snapshot_Delete_Entry(snapshot, file);
    DECREF(file);
}

void
DocWriter_finish(DocWriter *self)
{
    if (self->dat_out) {
        /* Write one final file pointer, so that we can derive the length of
         * the last record. */
        i64_t end = OutStream_Tell(self->dat_out);
        OutStream_Write_U64(self->ix_out, end);
        
        /* Close down output streams. */
        OutStream_Close(self->dat_out);
        OutStream_Close(self->ix_out);
        Seg_Store_Metadata_Str(self->segment, "documents", 9, 
            (Obj*)DocWriter_Metadata(self));
    }
}

i32_t
DocWriter_format(DocWriter *self)
{
    UNUSED_VAR(self);
    return DocWriter_current_file_format;
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

