#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SortReader.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Index/SortCache/NumericSortCache.h"
#include "KinoSearch/Index/SortCache/TextSortCache.h"
#include "KinoSearch/Index/SortWriter.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/I32Array.h"

SortReader*
SortReader_init(SortReader *self, Schema *schema, Folder *folder,
                Snapshot *snapshot, VArray *segments, i32_t seg_tick)
{
    DataReader_init((DataReader*)self, schema, folder, snapshot, segments,
        seg_tick);
    ABSTRACT_CLASS_CHECK(self, SORTREADER);
    return self;
}

DataReader*
SortReader_aggregator(SortReader *self, VArray *readers, I32Array *offsets)
{
    UNUSED_VAR(self);
    UNUSED_VAR(readers);
    UNUSED_VAR(offsets);
    return NULL;
}

DefaultSortReader*
DefSortReader_new(Schema *schema, Folder *folder, Snapshot *snapshot, 
               VArray *segments, i32_t seg_tick)
{
    DefaultSortReader *self 
        = (DefaultSortReader*)VTable_Make_Obj(DEFAULTSORTREADER);
    return DefSortReader_init(self, schema, folder, snapshot, segments,
        seg_tick);
}

DefaultSortReader*
DefSortReader_init(DefaultSortReader *self, Schema *schema, Folder *folder,
                   Snapshot *snapshot, VArray *segments, i32_t seg_tick)
{
    Segment *segment;
    Hash    *metadata;
    DataReader_init((DataReader*)self, schema, folder, snapshot, segments,
        seg_tick);
    segment = DefSortReader_Get_Segment(self);
    metadata = (Hash*)Seg_Fetch_Metadata_Str(segment, "sort", 4);
    
    /* Check format. */
    if (metadata) {
        Obj *format = Hash_Fetch_Str(metadata, "format", 6);
        if (!format) { THROW(ERR, "Missing 'format' var"); }
        else {
            if (Obj_To_I64(format) != SortWriter_current_file_format) {
                THROW(ERR, "Unsupported term vectors format: %i64", 
                    Obj_To_I64(format));
            }
        }
    }

    /* Init. */
    self->caches = Hash_new(0);

    /* Either extract or fake up the "counts" hash. */
    if (metadata) {
        self->counts = (Hash*)INCREF(ASSERT_IS_A(
            Hash_Fetch_Str(metadata, "counts", 6), HASH));
        self->null_ords = (Hash*)Hash_Fetch_Str(metadata, "null_ords", 9);
        if (self->null_ords) {
            ASSERT_IS_A(self->null_ords, HASH);
            INCREF(self->null_ords);
        }
        else {
            self->null_ords = Hash_new(0);
        }
    }
    else {
        self->counts    = Hash_new(0);
        self->null_ords = Hash_new(0);
    }

    return self;
}

void
DefSortReader_close(DefaultSortReader *self)
{
    if (self->caches) {
        Hash_Dec_RefCount(self->caches);
        self->caches = NULL;
    }
    if (self->counts) {
        Hash_Dec_RefCount(self->counts);
        self->counts = NULL;
    }
    if (self->null_ords) {
        Hash_Dec_RefCount(self->null_ords);
        self->null_ords = NULL;
    }
}

void
DefSortReader_destroy(DefaultSortReader *self)
{
    DECREF(self->caches);
    DECREF(self->counts);
    DECREF(self->null_ords);
    SUPER_DESTROY(self, DEFAULTSORTREADER);
}

SortCache*
DefSortReader_fetch_sort_cache(DefaultSortReader *self, const CharBuf *field)
{
    SortCache *cache = NULL;

    if (field) {
        cache = (SortCache*)Hash_Fetch(self->caches, (Obj*)field);
        if (!cache) {
            Obj *count = Hash_Fetch(self->counts, (Obj*)field);
            if (count) {
                Schema    *schema    = DefSortReader_Get_Schema(self);
                Folder    *folder    = DefSortReader_Get_Folder(self);
                Segment   *segment   = DefSortReader_Get_Segment(self);
                i32_t      field_num = Seg_Field_Num(segment, field);
                FieldType *type      = Schema_Fetch_Type(schema, field);
                i8_t       prim_id   = FType_Primitive_ID(type);
                Obj *null_ord_obj 
                    = Hash_Fetch(self->null_ords, (Obj*)field);
                i32_t null_ord = null_ord_obj 
                               ?  (i32_t)Obj_To_I64(null_ord_obj) : -1;
                switch (prim_id & FType_PRIMITIVE_ID_MASK) {
                    case FType_TEXT:
                        cache = (SortCache*)TextSortCache_new(schema, folder,
                            segment, field_num, (i32_t)Obj_To_I64(count), 
                            null_ord);
                        break;
                    case FType_INT32:
                        cache = (SortCache*)I32SortCache_new(schema, folder,
                            segment, field_num, (i32_t)Obj_To_I64(count), 
                            null_ord);
                        break;
                    case FType_INT64:
                        cache = (SortCache*)I64SortCache_new(schema, folder,
                            segment, field_num, (i32_t)Obj_To_I64(count), 
                            null_ord);
                        break;
                    case FType_FLOAT32:
                        cache = (SortCache*)F32SortCache_new(schema, folder,
                            segment, field_num, (i32_t)Obj_To_I64(count), 
                            null_ord);
                        break;
                    case FType_FLOAT64:
                        cache = (SortCache*)F64SortCache_new(schema, folder,
                            segment, field_num, (i32_t)Obj_To_I64(count), 
                            null_ord);
                        break;
                    default:
                        THROW(ERR, "No SortCache class for %o", type);
                }
                Hash_Store(self->caches, (Obj*)field, (Obj*)cache);
            }
        }
    }

    return cache;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

