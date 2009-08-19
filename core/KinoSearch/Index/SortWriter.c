#include "KinoSearch/Util/ToolSet.h"
#include <math.h>

#include "KinoSearch/Index/SortWriter.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/Inverter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Index/SortCache.h"
#include "KinoSearch/Index/SortReader.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/MemManager.h"
#include "KinoSearch/Util/SortUtils.h"
#include "KinoSearch/Util/I32Array.h"

i32_t SortWriter_current_file_format = 2;

SortWriter*
SortWriter_new(Schema *schema, Snapshot *snapshot, Segment *segment,
               PolyReader *polyreader)
{
    SortWriter *self = (SortWriter*)VTable_Make_Obj(SORTWRITER);
    return SortWriter_init(self, schema, snapshot, segment, polyreader);
}

SortWriter*
SortWriter_init(SortWriter *self, Schema *schema, Snapshot *snapshot,
                Segment *segment, PolyReader *polyreader)
{
    u32_t field_max = Schema_Num_Fields(schema) + 1;
    DataWriter_init((DataWriter*)self, schema, snapshot, segment, polyreader);

    /* Init. */
    self->uniq_vals = VA_new(field_max);
    self->doc_vals  = VA_new(field_max);
    self->blanks    = VA_new(field_max);
    self->counts    = Hash_new(0);
    self->null_ords = Hash_new(0);

    return self;
}

void
SortWriter_destroy(SortWriter *self) 
{
    DECREF(self->uniq_vals);
    DECREF(self->doc_vals);
    DECREF(self->blanks);
    DECREF(self->counts);
    DECREF(self->null_ords);
    SUPER_DESTROY(self, SORTWRITER);
}

static Hash*
S_get_uniques_hash(SortWriter *self, i32_t field_num)
{
    Hash *uniques = (Hash*)VA_Fetch(self->uniq_vals, field_num);
    if (!uniques) {
        uniques = Hash_new(0);
        VA_Store(self->uniq_vals, field_num, (Obj*)uniques);
    }
    return uniques;
}

static VArray*
S_get_vals_array(SortWriter *self, i32_t field_num)
{
    VArray *vals = (VArray*)VA_Fetch(self->doc_vals, field_num);
    if (!vals) {
        vals = VA_new(0);
        VA_Store(self->doc_vals, field_num, (Obj*)vals);
    }
    return vals;
}

static Obj*
S_get_blank(SortWriter *self, i32_t field_num)
{
    Obj *blank = VA_Fetch(self->blanks, field_num);
    if (!blank) {
        CharBuf *field_name = (CharBuf*)ASSERT_IS_A(
            Seg_Field_Name(self->segment, field_num), CHARBUF);
        FieldType *type = (FieldType*)ASSERT_IS_A(
            Schema_Fetch_Type(self->schema, field_name), FIELDTYPE);
        blank = FType_Make_Blank(type);
        VA_Store(self->blanks, field_num, (Obj*)blank);
    }
    return blank;
}

static Obj*
S_get_unique_value(Hash *uniques, Obj *val)
{
    i32_t    hash_code = Obj_Hash_Code(val);
    Obj     *uniq_val  = Hash_Find_Key(uniques, val, hash_code);
    if (!uniq_val) { 
        Hash_Store(uniques, val, INCREF(&EMPTY)); 
        uniq_val = Hash_Find_Key(uniques, val, hash_code);
    }
    return uniq_val;
}

void
SortWriter_add_inverted_doc(SortWriter *self, Inverter *inverter, 
                            i32_t doc_id)
{
    i32_t field_num;

    Inverter_Iter_Init(inverter);
    while (0 != (field_num = Inverter_Next(inverter))) {
        FieldType *type = Inverter_Get_Type(inverter);
        if (FType_Sortable(type)) {
            /* Uniq-ify the value, and record it for this document. */
            Hash     *uniques   = S_get_uniques_hash(self, field_num);
            VArray   *vals      = S_get_vals_array(self, field_num);
            Obj      *field_val = Inverter_Get_Value(inverter);
            Obj      *uniq_val  = S_get_unique_value(uniques, field_val);
            VA_Store(vals, doc_id, INCREF(uniq_val));
        }
    }
}

void
SortWriter_add_segment(SortWriter *self, SegReader *reader, I32Array *doc_map)
{
    VArray      *fields  = Schema_All_Fields(self->schema);
    const u32_t  doc_max = SegReader_Doc_Max(reader);
    u32_t i, max;

    /* Proceed field-at-a-time, rather than doc-at-a-time. */
    for (i = 0, max = VA_Get_Size(fields); i < max; i++) {
        CharBuf *field = (CharBuf*)VA_Fetch(fields, i);
        SortReader *sort_reader 
            = (SortReader*)SegReader_Fetch(reader, SORTREADER->name);
        SortCache *cache = sort_reader 
            ? SortReader_Fetch_Sort_Cache(sort_reader, field) : NULL;
        if (cache) {
            i32_t          field_num = Seg_Field_Num(self->segment, field);
            Hash          *uniques   = S_get_uniques_hash(self, field_num);
            VArray        *vals      = S_get_vals_array(self, field_num);
            Obj           *value     = S_get_blank(self, field_num);
            u32_t j;

            VA_Grow(vals, VA_Get_Size(vals) + doc_max);

            /* Add all the values for this field. */
            for (j = 1; j <= doc_max; j++) {
                i32_t remapped = I32Arr_Get(doc_map, j);
                if (remapped) {
                    u32_t ord = SortCache_Ordinal(cache, j);
                    Obj *val = SortCache_Value(cache, ord, value);
                    if (val) {
                        Obj *uniq_val = S_get_unique_value(uniques, val);
                        VA_Store(vals, remapped, INCREF(uniq_val));
                    }
                }
            }
        }
    }
    DECREF(fields);
}

void
SortWriter_delete_segment(SortWriter *self, SegReader *reader)
{
    Snapshot *snapshot = SortWriter_Get_Snapshot(self);
    Segment  *segment  = SegReader_Get_Segment(reader);
    CharBuf  *seg_name = Seg_Get_Name(segment);
    Hash     *metadata = (Hash*)Seg_Fetch_Metadata_Str(segment, "sort", 4);

    if (metadata) {
        Hash *counts = (Hash*)ASSERT_IS_A(
            Hash_Fetch_Str(metadata, "counts", 6), HASH);
        CharBuf *field;
        Obj     *count;

        /* Delete files for each sorted field. */
        Hash_Iter_Init(counts);
        while (Hash_Iter_Next(counts, (Obj**)&field, &count)) {
            i32_t field_num = Seg_Field_Num(segment, field);
            CharBuf *ord_file 
                = CB_newf("%o/sort-%i32.ord", seg_name, field_num);
            CharBuf *ix_file  
                = CB_newf("%o/sort-%i32.ix",  seg_name, field_num);
            CharBuf *dat_file 
                = CB_newf("%o/sort-%i32.dat", seg_name, field_num);
            Snapshot_Delete_Entry(snapshot, ord_file);
            Snapshot_Delete_Entry(snapshot, ix_file);
            Snapshot_Delete_Entry(snapshot, dat_file);
            DECREF(ord_file);
            DECREF(ix_file);
            DECREF(dat_file);
        }
    }
}

/* Determine whether a field has any NULL values. */
static bool_t
S_has_nulls(VArray *vals, i32_t doc_max) {
    u32_t i;
    if ((u32_t)doc_max + 1 != VA_Get_Size(vals)) { return 1; }
    for (i = 1; i < (u32_t)doc_max; i++) {
        if (!VA_Fetch(vals, i)) { return 1; }
    }
    return 0;
}

typedef struct kino_SortWriter_sort_context {
    VArray    *vals;
    FieldType *type;
} kino_SortWriter_sort_context;

static i32_t
S_compare_doc_vals(void *context, const void *va, const void *vb)
{
    i32_t doc_id_a = *(i32_t*)va;
    i32_t doc_id_b = *(i32_t*)vb;
    kino_SortWriter_sort_context *stuff =
        (kino_SortWriter_sort_context*)context;
    VArray *doc_vals = stuff->vals;
    Obj *a = VA_Fetch(doc_vals, doc_id_a);
    Obj *b = VA_Fetch(doc_vals, doc_id_b);
    return FType_Compare_Values(stuff->type, a, b);
}

static i32_t
S_calc_width(i32_t num_uniq)
{
    if      (num_uniq <= 0x00000002) { return 1; }
    else if (num_uniq <= 0x00000004) { return 2; }
    else if (num_uniq <= 0x0000000F) { return 4; }
    else if (num_uniq <= 0x000000FF) { return 8; }
    else if (num_uniq <= 0x0000FFFF) { return 16; }
    else                             { return 32; }
}

static void
S_write_ord(void *ords, i32_t width, i32_t doc_id, i32_t ord)
{
    switch (width) {
        case 1: if (ord) { NumUtil_u1set(ords, doc_id); }
                break;
        case 2: NumUtil_u2set(ords, doc_id, ord);
                break;
        case 4: NumUtil_u4set(ords, doc_id, ord);
                break;
        case 8: {
                    u8_t *ints = (u8_t*)ords;
                    ints[doc_id] = ord;
                }
                break;
        case 16: 
                {
                    u16_t *ints = (u16_t*)ords;
                    ints[doc_id] = ord;
                }
                break;
        case 32: 
                {
                    u32_t *ints = (u32_t*)ords;
                    ints[doc_id] = ord;
                }
                break;
        default: THROW(ERR, "Invalid width: %i32", width);
    }
}

static INLINE bool_t 
SI_variable_width(i8_t prim_id) 
{
    switch(prim_id & FType_PRIMITIVE_ID_MASK) {
        case FType_TEXT:
        case FType_BLOB:
            return true;
        default:
            return false;
    }
}

static INLINE void
SI_write_val(Obj *val, i8_t prim_id, OutStream *ix_out, OutStream *dat_out)
{
    if (val) {
        switch (prim_id & FType_PRIMITIVE_ID_MASK) {
            case FType_TEXT: {
                CharBuf *string = (CharBuf*)val;
                OutStream_Write_I64(ix_out, OutStream_Tell(dat_out));
                OutStream_Write_Bytes(dat_out, (char*)CB_Get_Ptr8(string),
                    CB_Get_Size(string));
                break;
            }
            case FType_BLOB: {
                ByteBuf *byte_buf = (ByteBuf*)val;
                OutStream_Write_I64(ix_out, OutStream_Tell(dat_out));
                OutStream_Write_Bytes(dat_out, BB_Get_Buf(byte_buf),
                    BB_Get_Size(byte_buf));
                break;
            }
            case FType_INT32: {
                Integer32 *i32 = (Integer32*)val;
                OutStream_Write_I32(dat_out, Int32_Get_Value(i32));
                break;
            }
            case FType_INT64: {
                Integer64 *i64 = (Integer64*)val;
                OutStream_Write_I64(dat_out, Int64_Get_Value(i64));
                break;
            }
            case FType_FLOAT64: {
                Float64 *float64 = (Float64*)val;
                OutStream_Write_F64(dat_out, Float64_Get_Value(float64));
                break;
            }
            case FType_FLOAT32: {
                Float32 *float32 = (Float32*)val;
                OutStream_Write_F32(dat_out, Float32_Get_Value(float32));
                break;
            }
            default: 
                THROW(ERR, "Unrecognized primitive id: %i32", (i32_t)prim_id);
        }
    }
    else {
        switch (prim_id & FType_PRIMITIVE_ID_MASK) {
            case FType_TEXT:
            case FType_BLOB: 
                OutStream_Write_I64(ix_out, -1);
                break;
            case FType_INT32: 
                OutStream_Write_I32(dat_out, 0);
                break;
            case FType_INT64: 
                OutStream_Write_I64(dat_out, 0);
                break;
            case FType_FLOAT64:
                OutStream_Write_F64(dat_out, 0.0);
                break;
            case FType_FLOAT32:
                OutStream_Write_F32(dat_out, 0.0f);
                break;
            default: 
                THROW(ERR, "Unrecognized primitive id: %i32", (i32_t)prim_id);
        }
    }
}

static i32_t
S_finish_field(SortWriter *self, i32_t field_num, VArray *doc_vals, 
               Hash *uniques, FieldType *type, i32_t *null_ord)
{
    i8_t       prim_id   = FType_Primitive_ID(type);
    bool_t     var_width = SI_variable_width(prim_id);
    Snapshot  *snapshot  = SortWriter_Get_Snapshot(self);
    Folder    *folder    = SortWriter_Get_Folder(self);
    CharBuf   *seg_name  = Seg_Get_Name(self->segment);
    CharBuf   *ord_file  = CB_newf("%o/sort-%i32.ord", seg_name, field_num);
    CharBuf   *ix_file   = CB_newf("%o/sort-%i32.ix",  seg_name, field_num);
    CharBuf   *dat_file  = CB_newf("%o/sort-%i32.dat", seg_name, field_num);
    OutStream *ord_out   = Folder_Open_Out(folder, ord_file);
    OutStream *ix_out    = var_width
                         ? Folder_Open_Out(folder, ix_file)
                         : NULL;
    OutStream *dat_out   = Folder_Open_Out(folder, dat_file);
    i32_t      doc_max   = Seg_Get_Count(self->segment);
    bool_t     has_nulls = S_has_nulls(doc_vals, doc_max);
    i32_t      num_uniq  = Hash_Get_Size(uniques) + has_nulls;
    i32_t      width     = S_calc_width(num_uniq);
    size_t     size      = (doc_max + 1) * sizeof(i32_t);
    i32_t     *sorted    = MALLOCATE(doc_max + 1, i32_t);
    void      *ords      = MALLOCATE(doc_max + 1, i32_t);
    i32_t      count     = 0;
    Obj       *last_val;
    u32_t      i;
    kino_SortWriter_sort_context context;

    if (!ord_out)              { THROW(ERR, "Can't open '%o'", ord_file); }
    if (var_width && !ix_out)  { THROW(ERR, "Can't open '%o'", ix_file); }
    if (!dat_out)              { THROW(ERR, "Can't open '%o'", dat_file); }

    /* Add files to Snapshot. */
    Snapshot_Add_Entry(snapshot, ord_file);
    if (var_width) { Snapshot_Add_Entry(snapshot, ix_file); }
    Snapshot_Add_Entry(snapshot, dat_file);

    /* Get an array of sorted doc nums.  Leave 0 as 0. */
    for (i = 0; i <= (u32_t)doc_max; i++) { sorted[i] = i; }
    context.type = type; 
    context.vals = doc_vals;
    Sort_mergesort(sorted + 1, ords, doc_max, sizeof(i32_t),
        S_compare_doc_vals, &context);

    /* We just used the ords array as scratch, so zero it. */
    memset(ords, 0, size);

    /* Write dummy ord for invalid doc id 0. */
    S_write_ord(ords, width, 0, 0);

    /* Write first value. */
    count = 0;
    last_val = VA_Fetch(doc_vals, sorted[1]);
    SI_write_val(last_val, prim_id, ix_out, dat_out);
    if (!last_val) {
        *null_ord = count;
    }

    /* Write sorted values.  Build array of ords. */
    for (i = 1; i <= (u32_t)doc_max; i++) { 
        i32_t doc_id = sorted[i];
        Obj *val = VA_Fetch(doc_vals, doc_id);
        if (val != last_val) {
            count++;
            last_val = val;
            SI_write_val(val, prim_id, ix_out, dat_out);
            if (!val) {
                *null_ord = count;
            }
        }

        /* Fill in doc id's slot in ords array. */
        S_write_ord(ords, width, doc_id, count);
    }

    /* Write one extra file pointer so that we can always derive length. */
    if (var_width) {
        OutStream_Write_I64(ix_out, OutStream_Tell(dat_out));
    }

    /* Write ords. */
    {
        const double BITS_PER_BYTE = 8.0;
        double bytes_per_doc = width / BITS_PER_BYTE;
        double byte_count = ceil((doc_max + 1) * bytes_per_doc);
        OutStream_Write_Bytes(ord_out, (char*)ords, (size_t)byte_count);
    }

    OutStream_Close(ord_out);
    if (ix_out) { OutStream_Close(ix_out); }
    OutStream_Close(dat_out);
    MemMan_wrapped_free(ords);
    MemMan_wrapped_free(sorted);
    DECREF(dat_out);
    DECREF(ix_out);
    DECREF(ord_out);
    DECREF(dat_file);
    DECREF(ix_file);
    DECREF(ord_file);

    count++;
    if (count != num_uniq) {
        THROW(ERR, "ord mismatch with num_uniq: %i32 %i32", count, num_uniq);
    }

    return num_uniq;
}

void
SortWriter_finish(SortWriter *self)
{
    Schema *schema = SortWriter_Get_Schema(self);
    u32_t i, max;

    for (i = 1, max = VA_Get_Size(self->uniq_vals); i < max; i++) {
        VArray *doc_vals = (VArray*)VA_Fetch(self->doc_vals, i);
        if (doc_vals && VA_Get_Size(doc_vals)) {
            Hash *uniques = (Hash*)VA_Fetch(self->uniq_vals, i);
            CharBuf *field = Seg_Field_Name(self->segment, i);
            FieldType *type = Schema_Fetch_Type(schema, field);
            i32_t null_ord = -1;
            i32_t count 
                = S_finish_field(self, i, doc_vals, uniques, type, &null_ord);
            Hash_Store(self->counts, (Obj*)field, 
                (Obj*)CB_newf("%i32", count));
            if (null_ord != -1) {
                Hash_Store(self->null_ords, (Obj*)field, 
                    (Obj*)CB_newf("%i32", null_ord));
            }
        }
    }

    /* Store metadata. */
    Seg_Store_Metadata_Str(self->segment, "sort", 4,
        (Obj*)SortWriter_Metadata(self));
}

Hash*
SortWriter_metadata(SortWriter *self)
{
    Hash *const metadata  = DataWriter_metadata((DataWriter*)self);
    Hash_Store_Str(metadata, "counts", 6, INCREF(self->counts));
    Hash_Store_Str(metadata, "null_ords", 9, INCREF(self->null_ords));
    return metadata;
}

i32_t
SortWriter_format(SortWriter *self)
{
    UNUSED_VAR(self);
    return SortWriter_current_file_format;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

