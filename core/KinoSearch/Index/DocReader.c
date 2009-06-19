#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/DocReader.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/DocWriter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Util/I32Array.h"
#include "KinoSearch/Util/ByteBuf.h"

DocReader*
DocReader_init(DocReader *self, Schema *schema, Folder *folder, 
               Snapshot *snapshot, VArray *segments, i32_t seg_tick)
{
    return (DocReader*)DataReader_init((DataReader*)self, schema, folder, 
        snapshot, segments, seg_tick);
}

DocReader*
DocReader_aggregator(DocReader *self, VArray *readers, I32Array *offsets)
{
    UNUSED_VAR(self);
    return (DocReader*)PolyDocReader_new(readers, offsets);
}

PolyDocReader*
PolyDocReader_new(VArray *readers, I32Array *offsets)
{
    PolyDocReader *self = (PolyDocReader*)VTable_Make_Obj(&POLYDOCREADER);
    return PolyDocReader_init(self, readers, offsets);
}

PolyDocReader*
PolyDocReader_init(PolyDocReader *self, VArray *readers, I32Array *offsets)
{
    u32_t i, max;
    DocReader_init((DocReader*)self, NULL, NULL, NULL, NULL, -1);
    for (i = 0, max = VA_Get_Size(readers); i < max; i++) {
        ASSERT_IS_A(VA_Fetch(readers, i), DOCREADER);
    }
    self->readers = (VArray*)INCREF(readers);
    self->offsets = (I32Array*)INCREF(offsets);
    return self;
}

void
PolyDocReader_close(PolyDocReader *self)
{
    if (self->readers) {
        u32_t i, max;
        for (i = 0, max = VA_Get_Size(self->readers); i < max; i++) {
            DocReader *reader = (DocReader*)VA_Fetch(self->readers, i);
            if (reader) { DocReader_Close(reader); }
        }
        VA_Clear(self->readers);
    }
}

void
PolyDocReader_destroy(PolyDocReader *self)
{
    DECREF(self->readers);
    DECREF(self->offsets);
    SUPER_DESTROY(self, POLYDOCREADER);
}

Obj*
PolyDocReader_fetch(PolyDocReader *self, i32_t doc_id, float score, 
                    i32_t offset)
{
    u32_t seg_tick  = PolyReader_sub_tick(self->offsets, doc_id);
    i32_t my_offset = I32Arr_Get(self->offsets, seg_tick);
    DocReader *doc_reader = (DocReader*)VA_Fetch(self->readers, seg_tick);
    Obj *hit = NULL;
    if (!doc_reader) { 
        THROW("Invalid doc_id: %i32", doc_id); 
    }
    else {
        hit = DocReader_Fetch(doc_reader, doc_id - my_offset, score, 
            offset + my_offset);
    }
    return hit;
}

DefaultDocReader*
DefDocReader_new(Schema *schema, Folder *folder, Snapshot *snapshot, 
                 VArray *segments, i32_t seg_tick)
{
    DefaultDocReader *self 
        = (DefaultDocReader*)VTable_Make_Obj(&DEFAULTDOCREADER);
    return DefDocReader_init(self, schema, folder, snapshot, segments,
        seg_tick);
}

void
DefDocReader_close(DefaultDocReader *self)
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
DefDocReader_destroy(DefaultDocReader *self)
{
    DECREF(self->ix_in);
    DECREF(self->dat_in);
    SUPER_DESTROY(self, DEFAULTDOCREADER);
}

DefaultDocReader*
DefDocReader_init(DefaultDocReader *self, Schema *schema, Folder *folder, 
                  Snapshot *snapshot, VArray *segments, i32_t seg_tick)
{
    Hash *metadata; 
    Segment *segment;
    DocReader_init((DocReader*)self, schema, folder, snapshot, segments,
        seg_tick);
    segment = DefDocReader_Get_Segment(self);
    metadata = (Hash*)Seg_Fetch_Metadata_Str(segment, "documents", 9);

    if (metadata) {
        CharBuf *seg_name  = Seg_Get_Name(segment);
        CharBuf *ix_file   = CB_newf("%o/documents.ix", seg_name);
        CharBuf *dat_file  = CB_newf("%o/documents.dat", seg_name);
        Obj     *format    = Hash_Fetch_Str(metadata, "format", 6);

        /* Check format. */
        if (!format) { THROW("Missing 'format' var"); }
        else {
            i64_t format_val = Obj_To_I64(format);
            if (format_val < DocWriter_current_file_format) {
                THROW("Obsolete doc storage format %i64; "
                    "Index regeneration is required", format_val);
            }
            else if (format_val != DocWriter_current_file_format) {
                THROW("Unsupported doc storage format: %i64", format_val);
            }
        }

        /* Get streams. */
        if (Folder_Exists(folder, ix_file)) {
            self->ix_in  = Folder_Open_In(folder, ix_file);
            self->dat_in = Folder_Open_In(folder, dat_file);
            if (!self->ix_in || !self->dat_in) {
                CharBuf *mess = MAKE_MESS("Can't open either %o or %o",
                    ix_file, dat_file);
                DECREF(ix_file);
                DECREF(dat_file);
                DECREF(self);
                Err_throw_mess(mess);
            }
        }
        DECREF(ix_file);
        DECREF(dat_file);
    }
    
    return self;
}

void
DefDocReader_read_record(DefaultDocReader *self, ByteBuf *buffer,
                         i32_t doc_id)
{
    i64_t start;
    i64_t end;
    i32_t size;

    /* Find start and length of variable length record. */
    InStream_Seek(self->ix_in, (i64_t)doc_id * 8);
    start = InStream_Read_U64(self->ix_in);
    end   = InStream_Read_U64(self->ix_in);
    size  = end - start;

    /* Read in the record. */
    BB_Grow(buffer, size);
    InStream_Seek(self->dat_in, start);
    InStream_Read_Bytes(self->dat_in, buffer->ptr, size);
    BB_Set_Size(buffer, size);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

