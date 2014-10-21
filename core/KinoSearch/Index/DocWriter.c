#define C_KINO_DOCWRITER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/DocWriter.h"
#include "KinoSearch/Document/Doc.h"
#include "KinoSearch/Index/DocReader.h"
#include "KinoSearch/Index/Inverter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Plan/FieldType.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/OutStream.h"

static OutStream*
S_lazy_init(DocWriter *self);

int32_t DocWriter_current_file_format = 2;

DocWriter*
DocWriter_new(Schema *schema, Snapshot *snapshot, Segment *segment, 
              PolyReader *polyreader)
{
    DocWriter *self = (DocWriter*)VTable_Make_Obj(DOCWRITER);
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
        Folder   *folder    = self->folder;
        CharBuf  *seg_name  = Seg_Get_Name(self->segment);

        // Get streams. 
        {
            CharBuf *ix_file = CB_newf("%o/documents.ix", seg_name);
            self->ix_out = Folder_Open_Out(folder, ix_file);
            DECREF(ix_file);
            if (!self->ix_out) { RETHROW(INCREF(Err_get_error())); }
        }
        {
            CharBuf *dat_file = CB_newf("%o/documents.dat", seg_name);
            self->dat_out = Folder_Open_Out(folder, dat_file);
            DECREF(dat_file);
            if (!self->dat_out) { RETHROW(INCREF(Err_get_error())); }
        }

        // Go past non-doc #0. 
        OutStream_Write_I64(self->ix_out, 0);
    }

    return self->dat_out;
}

void
DocWriter_add_inverted_doc(DocWriter *self, Inverter *inverter, 
                           int32_t doc_id)
{
    OutStream *dat_out         = S_lazy_init(self);
    OutStream *ix_out          = self->ix_out;
    uint32_t   num_stored      = 0;
    int64_t    start           = OutStream_Tell(dat_out);
    int64_t    expected        = OutStream_Tell(ix_out) / 8;

    // Verify doc id. 
    if (doc_id != expected)
        THROW(ERR, "Expected doc id %i64 but got %i32", expected, doc_id);

    // Write the number of stored fields. 
    Inverter_Iterate(inverter);
    while (Inverter_Next(inverter)) {
        FieldType *type = Inverter_Get_Type(inverter);
        if (FType_Stored(type)) { num_stored++; }
    }
    OutStream_Write_C32(dat_out, num_stored);

    Inverter_Iterate(inverter);
    while (Inverter_Next(inverter)) {
        // Only store fields marked as "stored". 
        FieldType *type = Inverter_Get_Type(inverter);
        if (FType_Stored(type)) {
            CharBuf *field = Inverter_Get_Field_Name(inverter);
            Obj *value = Inverter_Get_Value(inverter);
            CB_Serialize(field, dat_out);
            Obj_Serialize(value, dat_out);
        }
    }

    // Write file pointer. 
    OutStream_Write_I64(ix_out, start);
}

void
DocWriter_add_segment(DocWriter *self, SegReader *reader, 
                      I32Array *doc_map)
{
    int32_t doc_max = SegReader_Doc_Max(reader);

    if (doc_max == 0) {
        // Bail if the supplied segment is empty. 
        return;
    }
    else {
        OutStream     *const dat_out    = S_lazy_init(self);
        OutStream     *const ix_out     = self->ix_out;
        ByteBuf       *const buffer     = BB_new(0);
        DefaultDocReader *const doc_reader = (DefaultDocReader*)CERTIFY(
            SegReader_Obtain(reader, VTable_Get_Name(DOCREADER)), 
                DEFAULTDOCREADER);
        int32_t i, max;

        for (i = 1, max = SegReader_Doc_Max(reader); i <= max; i++) {
            if (I32Arr_Get(doc_map, i)) {
                int64_t  start = OutStream_Tell(dat_out);
                char    *buf;
                size_t   size;

                // Copy record over.  
                DefDocReader_Read_Record(doc_reader, buffer, i);
                buf  = BB_Get_Buf(buffer);
                size = BB_Get_Size(buffer);
                OutStream_Write_Bytes(dat_out, buf, size);

                // Write file pointer. 
                OutStream_Write_I64(ix_out, start);
            }
        }

        DECREF(buffer);
    }
}

void
DocWriter_finish(DocWriter *self)
{
    if (self->dat_out) {
        // Write one final file pointer, so that we can derive the length of
        // the last record.
        int64_t end = OutStream_Tell(self->dat_out);
        OutStream_Write_I64(self->ix_out, end);
        
        // Close down output streams. 
        OutStream_Close(self->dat_out);
        OutStream_Close(self->ix_out);
        Seg_Store_Metadata_Str(self->segment, "documents", 9, 
            (Obj*)DocWriter_Metadata(self));
    }
}

int32_t
DocWriter_format(DocWriter *self)
{
    UNUSED_VAR(self);
    return DocWriter_current_file_format;
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

