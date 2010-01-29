#define C_KINO_NUMERICSORTCACHE
#define C_KINO_INT32SORTCACHE
#define C_KINO_INT64SORTCACHE
#define C_KINO_FLOAT32SORTCACHE
#define C_KINO_FLOAT64SORTCACHE
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SortCache/NumericSortCache.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/FieldType/NumericType.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/Folder.h"

NumericSortCache*
NumSortCache_init(NumericSortCache *self, Schema *schema, Folder *folder,
                  Segment *segment, i32_t field_num, i32_t num_unique,
                  i32_t null_ord, size_t unit_width)
{
    CharBuf   *field    = Seg_Field_Name(segment, field_num);
    CharBuf   *seg_name = Seg_Get_Name(segment);
    FieldType *type     = Schema_Fetch_Type(schema, field);
    i32_t      doc_max  = (int32_t)Seg_Get_Count(segment);
    i64_t      ord_len;
    i64_t      dat_len;
    void      *ords;

    /* Validate. */
    if (!type || !FType_Sortable(type) || !FType_Is_A(type, NUMERICTYPE)) {
        DECREF(self);
        THROW(ERR, "'%o' isn't a sortable NumericType field", field);
    }

    /* Open instreams. */
    {
        CharBuf *ord_file = CB_newf("%o/sort-%i32.ord", seg_name, field_num);
        self->ord_in = Folder_Open_In(folder, ord_file);
        DECREF(ord_file);
        if (!self->ord_in) {
            Err *error = Err_new(CB_newf( 
                "Error building sort cache for '%o': %o", field,
                Err_get_error()));
            DECREF(self);
            Err_do_throw(error);
        }
    }
    {
        CharBuf *dat_file = CB_newf("%o/sort-%i32.dat", seg_name, field_num);
        self->dat_in = Folder_Open_In(folder, dat_file);
        DECREF(dat_file);
        if (!self->dat_in) {
            Err *error = Err_new(CB_newf( 
                "Error building sort cache for '%o': %o", field,
                Err_get_error()));
            DECREF(self);
            Err_do_throw(error);
        }
    }

    /* Mmap ords and raw data. */
    ord_len            = InStream_Length(self->ord_in);
    dat_len            = InStream_Length(self->dat_in);
    ords               = InStream_Buf(self->ord_in, (size_t)ord_len);
    self->values       = InStream_Buf(self->dat_in, (size_t)dat_len);
    self->values_limit = self->values + dat_len;

    /* Super-init. */
    SortCache_init((SortCache*)self, field, type, ords, num_unique, doc_max,
        null_ord);

    /* Validate ord file length. */
    {
        const double BITS_PER_BYTE = 8.0;
        double docs_per_byte = BITS_PER_BYTE / self->ord_width;
        double max_ords      = ord_len * docs_per_byte;
        if (max_ords < self->doc_max + 1) {
            DECREF(self);
            THROW(ERR, "Conflict between ord count max %f64 and doc_max %i32 for "
                "field %o", max_ords, self->doc_max, field);
        }
    }

    /* Validate dat file length. */
    {
        char *limit = self->values + self->num_uniq * unit_width;
        if (self->values_limit != limit) {
            i64_t wanted = limit - self->values;
            i64_t got    = self->values_limit - self->values;
            DECREF(self);
            THROW(ERR, "Sort cache data file for %o should be %i64 bytes, "
                "not %i64", field, wanted, got);
        }
    }

    ABSTRACT_CLASS_CHECK(self, NUMERICSORTCACHE);
    return self;
}

void
NumSortCache_destroy(NumericSortCache *self)
{
    if (self->ord_in) { 
        InStream_Close(self->ord_in); 
        InStream_Dec_RefCount(self->ord_in);
    }
    if (self->dat_in) { 
        InStream_Close(self->dat_in); 
        InStream_Dec_RefCount(self->dat_in);
    }
    SUPER_DESTROY(self, NUMERICSORTCACHE);
}

/***************************************************************************/

Float64SortCache*
F64SortCache_new(Schema *schema, Folder *folder, Segment *segment, 
                 i32_t field_num, i32_t num_unique, i32_t null_ord)
{
    Float64SortCache *self 
        = (Float64SortCache*)VTable_Make_Obj(FLOAT64SORTCACHE);
    return F64SortCache_init(self, schema, folder, segment, field_num,
        num_unique, null_ord);
}

Float64SortCache*
F64SortCache_init(Float64SortCache *self, Schema *schema, Folder *folder,
                  Segment *segment, i32_t field_num, i32_t num_unique,
                  i32_t null_ord)
{
    CharBuf   *field = Seg_Field_Name(segment, field_num);
    FieldType *type  = Schema_Fetch_Type(schema, field);
    if (!type || !FType_Sortable(type) || !FType_Is_A(type, FLOAT64TYPE)) {
        THROW(ERR, "'%o' isn't a sortable Float64Type field", field);
    }
    NumSortCache_init((NumericSortCache*)self, schema, folder, segment, 
        field_num, num_unique, null_ord, sizeof(double));
    return self;
}

Obj*
F64SortCache_value(Float64SortCache *self, i32_t ord, Obj *blank)
{
    if (ord == self->null_ord ) {
        return NULL; 
    }
    else if (ord < 0) {
        THROW(ERR, "Ordinal less than 0 for %o: %i32", self->field, ord);
    }
    else {
        char *val_ptr = self->values + ord * sizeof(double);
        Float64 *num_blank = (Float64*)CERTIFY(blank, FLOAT64);
        if (val_ptr > self->values_limit) {
            i64_t over = val_ptr - self->values_limit;
            THROW(ERR, "Read %i64 beyond data limit for %o", over, self->field);
        }
        #ifdef LITTLE_END
        {
            u64_t reversed_bytes = NumUtil_decode_bigend_u64(val_ptr);
            Float64_Set_Value(num_blank, *((double*)&reversed_bytes));
        }
        #else 
        Float64_Set_Value(num_blank, *(double*)val_ptr);
        #endif
    }
    return blank;
}

/***************************************************************************/

Float32SortCache*
F32SortCache_new(Schema *schema, Folder *folder, Segment *segment, 
                 i32_t field_num, i32_t num_unique, i32_t null_ord)
{
    Float32SortCache *self 
        = (Float32SortCache*)VTable_Make_Obj(FLOAT32SORTCACHE);
    return F32SortCache_init(self, schema, folder, segment, field_num,
        num_unique, null_ord);
}

Float32SortCache*
F32SortCache_init(Float32SortCache *self, Schema *schema, Folder *folder,
                  Segment *segment, i32_t field_num, i32_t num_unique,
                  i32_t null_ord)
{
    CharBuf   *field = Seg_Field_Name(segment, field_num);
    FieldType *type  = Schema_Fetch_Type(schema, field);
    if (!type || !FType_Sortable(type) || !FType_Is_A(type, FLOAT32TYPE)) {
        THROW(ERR, "'%o' isn't a sortable Float32Type field", field);
    }
    NumSortCache_init((NumericSortCache*)self, schema, folder, segment, 
        field_num, num_unique, null_ord, sizeof(float));
    return self;
}

Obj*
F32SortCache_value(Float32SortCache *self, i32_t ord, Obj *blank)
{
    if (ord == self->null_ord ) {
        return NULL; 
    }
    else if (ord < 0) {
        THROW(ERR, "Ordinal less than 0 for %o: %i32", self->field, ord);
    }
    else {
        char *val_ptr = self->values + ord * sizeof(float);
        Float32 *num_blank = (Float32*)CERTIFY(blank, FLOAT32);
        if (val_ptr > self->values_limit) {
            i64_t over = val_ptr - self->values_limit;
            THROW(ERR, "Read %i64 beyond data limit for %o", over, self->field);
        }
        #ifdef LITTLE_END
        {
            u32_t reversed_bytes = NumUtil_decode_bigend_u32(val_ptr);
            Float32_Set_Value(num_blank, *((float*)&reversed_bytes));
        }
        #else 
        Float32_Set_Value(num_blank, *(float*)val_ptr);
        #endif
    }
    return blank;
}

/***************************************************************************/

Int32SortCache*
I32SortCache_new(Schema *schema, Folder *folder, Segment *segment, 
                 i32_t field_num, i32_t num_unique, i32_t null_ord)
{
    Int32SortCache *self 
        = (Int32SortCache*)VTable_Make_Obj(INT32SORTCACHE);
    return I32SortCache_init(self, schema, folder, segment, field_num,
        num_unique, null_ord);
}

Int32SortCache*
I32SortCache_init(Int32SortCache *self, Schema *schema, Folder *folder,
                  Segment *segment, i32_t field_num, i32_t num_unique,
                  i32_t null_ord)
{
    CharBuf   *field = Seg_Field_Name(segment, field_num);
    FieldType *type  = Schema_Fetch_Type(schema, field);
    if (!type || !FType_Sortable(type) || !FType_Is_A(type, INT32TYPE)) {
        THROW(ERR, "'%o' isn't a sortable Int32Type field", field);
    }
    NumSortCache_init((NumericSortCache*)self, schema, folder, segment, 
        field_num, num_unique, null_ord, sizeof(i32_t));
    return self;
}

Obj*
I32SortCache_value(Int32SortCache *self, i32_t ord, Obj *blank)
{
    if (ord == self->null_ord ) {
        return NULL; 
    }
    else if (ord < 0) {
        THROW(ERR, "Ordinal less than 0 for %o: %i32", self->field, ord);
    }
    else {
        char *val_ptr = self->values + ord * sizeof(i32_t);
        Integer32 *int_blank = (Integer32*)CERTIFY(blank, INTEGER32);
        if (val_ptr > self->values_limit) {
            i64_t over = val_ptr - self->values_limit;
            THROW(ERR, "Read %i64 beyond data limit for %o", over, self->field);
        }
        Int32_Set_Value(int_blank, NumUtil_decode_bigend_u32(val_ptr));
    }
    return blank;
}

/***************************************************************************/

Int64SortCache*
I64SortCache_new(Schema *schema, Folder *folder, Segment *segment, 
                 i32_t field_num, i32_t num_unique, i32_t null_ord)
{
    Int64SortCache *self 
        = (Int64SortCache*)VTable_Make_Obj(INT64SORTCACHE);
    return I64SortCache_init(self, schema, folder, segment, field_num,
        num_unique, null_ord);
}

Int64SortCache*
I64SortCache_init(Int64SortCache *self, Schema *schema, Folder *folder,
                  Segment *segment, i32_t field_num, i32_t num_unique,
                  i32_t null_ord)
{
    CharBuf   *field = Seg_Field_Name(segment, field_num);
    FieldType *type  = Schema_Fetch_Type(schema, field);
    if (!type || !FType_Sortable(type) || !FType_Is_A(type, INT64TYPE)) {
        THROW(ERR, "'%o' isn't a sortable Int64Type field", field);
    }
    NumSortCache_init((NumericSortCache*)self, schema, folder, segment, 
        field_num, num_unique, null_ord, sizeof(i64_t));
    return self;
}

Obj*
I64SortCache_value(Int64SortCache *self, i32_t ord, Obj *blank)
{
    if (ord == self->null_ord ) {
        return NULL; 
    }
    else if (ord < 0) {
        THROW(ERR, "Ordinal less than 0 for %o: %i32", self->field, ord);
    }
    else {
        char *val_ptr = self->values + ord * sizeof(i64_t);
        Integer64 *int_blank = (Integer64*)CERTIFY(blank, INTEGER64);
        if (val_ptr > self->values_limit) {
            i64_t over = val_ptr - self->values_limit;
            THROW(ERR, "Read %i64 beyond data limit for %o", over, self->field);
        }
        Int64_Set_Value(int_blank, NumUtil_decode_bigend_u64(val_ptr));
    }
    return blank;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

