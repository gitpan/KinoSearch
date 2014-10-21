#define C_KINO_HIGHLIGHTREADER
#define C_KINO_POLYHIGHLIGHTREADER
#define C_KINO_DEFAULTHIGHLIGHTREADER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/HighlightReader.h"
#include "KinoSearch/Index/DocVector.h"
#include "KinoSearch/Index/HighlightWriter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Store/Folder.h"

HighlightReader*
HLReader_init(HighlightReader *self, Schema *schema, Folder *folder,
              Snapshot *snapshot, VArray *segments, int32_t seg_tick)
{
    DataReader_init((DataReader*)self, schema, folder, snapshot, segments,
        seg_tick);
    ABSTRACT_CLASS_CHECK(self, HIGHLIGHTREADER);
    return self;
}

HighlightReader*
HLReader_aggregator(HighlightReader *self, VArray *readers, 
                    I32Array *offsets)
{
    UNUSED_VAR(self);
    return (HighlightReader*)PolyHLReader_new(readers, offsets);
}

PolyHighlightReader*
PolyHLReader_new(VArray *readers, I32Array *offsets)
{
    PolyHighlightReader *self 
        = (PolyHighlightReader*)VTable_Make_Obj(POLYHIGHLIGHTREADER);
    return PolyHLReader_init(self, readers, offsets);
}

PolyHighlightReader*
PolyHLReader_init(PolyHighlightReader *self, VArray *readers, 
                   I32Array *offsets)
{
    uint32_t i, max;
    HLReader_init((HighlightReader*)self, NULL, NULL, NULL, NULL, -1);
    for (i = 0, max = VA_Get_Size(readers); i < max; i++) {
        CERTIFY(VA_Fetch(readers, i), HIGHLIGHTREADER);
    }
    self->readers = (VArray*)INCREF(readers);
    self->offsets = (I32Array*)INCREF(offsets);
    return self;
}

void
PolyHLReader_close(PolyHighlightReader *self)
{
    if (self->readers) {
        uint32_t i, max;
        for (i = 0, max = VA_Get_Size(self->readers); i < max; i++) {
            HighlightReader *sub_reader 
                = (HighlightReader*)VA_Fetch(self->readers, i);
            if (sub_reader) { HLReader_Close(sub_reader); }
        }
        DECREF(self->readers);
        DECREF(self->offsets);
        self->readers = NULL;
        self->offsets = NULL;
    }
}

void
PolyHLReader_destroy(PolyHighlightReader *self)
{
    DECREF(self->readers);
    DECREF(self->offsets);
    SUPER_DESTROY(self, POLYHIGHLIGHTREADER);
}

DocVector*
PolyHLReader_fetch(PolyHighlightReader *self, int32_t doc_id)
{
    uint32_t seg_tick = PolyReader_sub_tick(self->offsets, doc_id);
    int32_t offset   = I32Arr_Get(self->offsets, seg_tick);
    HighlightReader *sub_reader 
        = (HighlightReader*)VA_Fetch(self->readers, seg_tick);
    if (!sub_reader) { THROW(ERR, "Invalid doc_id: %i32", doc_id); }
    return HLReader_Fetch(sub_reader, doc_id - offset);
}

DefaultHighlightReader*
DefHLReader_new(Schema *schema, Folder *folder, Snapshot *snapshot, 
                VArray *segments, int32_t seg_tick)
{
    DefaultHighlightReader *self = (DefaultHighlightReader*)
        VTable_Make_Obj(DEFAULTHIGHLIGHTREADER);
    return DefHLReader_init(self, schema, folder, snapshot, segments, 
        seg_tick);
}

DefaultHighlightReader*
DefHLReader_init(DefaultHighlightReader *self, Schema *schema,
                 Folder *folder, Snapshot *snapshot, VArray *segments,
                 int32_t seg_tick)
{
    Segment *segment;
    Hash    *metadata; 
    HLReader_init((HighlightReader*)self, schema, folder, snapshot,
        segments, seg_tick);
    segment  = DefHLReader_Get_Segment(self);
    metadata = (Hash*)Seg_Fetch_Metadata_Str(segment, "highlight", 9);
    if (!metadata) {
        metadata = (Hash*)Seg_Fetch_Metadata_Str(segment, "term_vectors", 12);
    }
    
    // Check format. 
    if (metadata) {
        Obj     *format    = Hash_Fetch_Str(metadata, "format", 6);
        if (!format) { THROW(ERR, "Missing 'format' var"); }
        else {
            if (Obj_To_I64(format) != HLWriter_current_file_format) {
                THROW(ERR, "Unsupported highlight data format: %i64", 
                    Obj_To_I64(format));
            }
        }
    }


    // Open instreams. 
    {
        CharBuf *seg_name = Seg_Get_Name(segment);
        CharBuf *ix_file  = CB_newf("%o/highlight.ix", seg_name);
        CharBuf *dat_file = CB_newf("%o/highlight.dat", seg_name);
        if (Folder_Exists(folder, ix_file)) {
            self->ix_in = Folder_Open_In(folder, ix_file);
            if (!self->ix_in) {
                Err *error = (Err*)INCREF(Err_get_error());
                DECREF(ix_file);
                DECREF(dat_file);
                DECREF(self);
                RETHROW(error);
            }   
            self->dat_in = Folder_Open_In(folder, dat_file);
            if (!self->dat_in) {
                Err *error = (Err*)INCREF(Err_get_error());
                DECREF(ix_file);
                DECREF(dat_file);
                DECREF(self);
                RETHROW(error);
            }   
        }   
        DECREF(ix_file);
        DECREF(dat_file);
    }

    return self;
}

void
DefHLReader_close(DefaultHighlightReader *self)
{
    if (self->dat_in != NULL) {
        InStream_Close(self->dat_in);
        DECREF(self->dat_in);
        self->dat_in = NULL;
    }
    if (self->ix_in != NULL) {
        InStream_Close(self->ix_in);
        DECREF(self->ix_in);
        self->ix_in = NULL;
    }
}

void
DefHLReader_destroy(DefaultHighlightReader *self)
{
    DECREF(self->ix_in);
    DECREF(self->dat_in);
    SUPER_DESTROY(self, DEFAULTHIGHLIGHTREADER);
}

DocVector*
DefHLReader_fetch(DefaultHighlightReader *self, int32_t doc_id)
{
    DocVector *doc_vec = DocVec_new();
    int64_t file_pos;
    uint32_t num_fields;

    InStream_Seek(self->ix_in, doc_id * 8);
    file_pos = InStream_Read_I64(self->ix_in);
    InStream_Seek(self->dat_in, file_pos);

    num_fields = InStream_Read_C32(self->dat_in);
    while (num_fields--) {
        CharBuf *field = CB_deserialize(NULL, self->dat_in);
        ByteBuf *field_buf  = BB_deserialize(NULL, self->dat_in);
        DocVec_Add_Field_Buf(doc_vec, field, field_buf);
        DECREF(field_buf);
        DECREF(field);
    }

    return doc_vec;
}

void
DefHLReader_read_record(DefaultHighlightReader *self, int32_t doc_id,
                        ByteBuf *target)
{
    InStream *dat_in = self->dat_in;
    InStream *ix_in  = self->ix_in;

    InStream_Seek(ix_in, doc_id * 8);

    {
        // Copy the whole record. 
        int64_t  filepos = InStream_Read_I64(ix_in);
        int64_t  end     = InStream_Read_I64(ix_in);
        size_t   size    = (size_t)(end - filepos);
        char    *buf     = BB_Grow(target, size);
        InStream_Seek(dat_in, filepos);
        InStream_Read_Bytes(dat_in, buf, size);
        BB_Set_Size(target, size);
    }
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

