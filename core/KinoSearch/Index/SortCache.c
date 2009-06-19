#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SortCache.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/IntArrays.h"

SortCache*
SortCache_new(Schema *schema, Folder *folder, Segment *segment, 
              i32_t field_num)
{
    SortCache *self = (SortCache*)VTable_Make_Obj(&SORTCACHE);
    return SortCache_init(self, schema, folder, segment, field_num);
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

SortCache*
SortCache_init(SortCache *self, Schema *schema, Folder *folder,
               Segment *segment, i32_t field_num)
{
    CharBuf *field    = Seg_Field_Name(segment, field_num);
    CharBuf *seg_name = Seg_Get_Name(segment);
    CharBuf *ord_file = CB_newf("%o/sort-%i32.ord", seg_name, field_num);
    CharBuf *ix_file  = CB_newf("%o/sort-%i32.ix",  seg_name, field_num);
    CharBuf *dat_file = CB_newf("%o/sort-%i32.dat", seg_name, field_num);
    i64_t ord_len, ix_len, dat_len;

    /* Derive. */
    self->doc_max = Seg_Get_Count(segment);
    self->type    = Schema_Fetch_Type(schema, field);
    if (!self->type || !FType_Sortable(self->type)) {
        THROW("'%o' isn't a sortable field", field);
    }

    /* Open instreams. */
    self->ord_in  = Folder_Open_In(folder, ord_file);
    self->ix_in   = Folder_Open_In(folder, ix_file);
    self->dat_in  = Folder_Open_In(folder, dat_file);
    if (!self->ix_in || !self->dat_in || !self->ord_in) {
        CharBuf *mess = MAKE_MESS("Can't open either %o, %o or %o", ord_file, 
            ix_file, dat_file);
        DECREF(ord_file);
        DECREF(ix_file);
        DECREF(dat_file);
        Err_throw_mess(mess);
    }
    ord_len = InStream_Length(self->ord_in);
    ix_len  = InStream_Length(self->ix_in);
    dat_len = InStream_Length(self->dat_in);

    /* Calculate the number of unique values and derive the ord bit width. */
    self->num_uniq = (i32_t)(ix_len / 8) - 1; 
    self->width    = S_calc_width(self->num_uniq);

    /* Validate file lengths. */
    {
        double bytes_per_doc = self->width / 8.0;
        double max_ords      = ord_len / bytes_per_doc;
        if (max_ords < self->doc_max + 1) {
            THROW("Conflict between ord count max %f64 and doc_max %i32", 
                max_ords, self->doc_max);
        }
    }

    /* Mmap ords, offsets and character data. */
    self->ords      = InStream_Buf(self->ord_in, (size_t)ord_len);
    self->offsets   = (i64_t*)InStream_Buf(self->ix_in, (size_t)ix_len);
    self->char_data = InStream_Buf(self->dat_in, dat_len);
    {
        char *offs            = (char*)self->offsets;
        self->offsets_limit   = (i64_t*)(offs + ix_len);
        self->char_data_limit = self->char_data + dat_len;
    }

    DECREF(ord_file);
    DECREF(ix_file);
    DECREF(dat_file);

    return self;
}

void
SortCache_destroy(SortCache *self)
{
    if (self->ord_in) { 
        InStream_Close(self->ord_in); 
        InStream_Dec_RefCount(self->ord_in);
    }
    if (self->ix_in) { 
        InStream_Close(self->ix_in); 
        InStream_Dec_RefCount(self->ix_in);
    }
    if (self->dat_in) { 
        InStream_Close(self->dat_in); 
        InStream_Dec_RefCount(self->dat_in);
    }
    FREE_OBJ(self);
}

static INLINE i64_t
SI_fetch_offset(SortCache *self, u32_t ord)
{
    i64_t *const offsets = self->offsets + ord;
    if (offsets >= self->offsets_limit) {
        THROW("Ordinal %u32 out of bounds (num unique: %i32)", ord,
            self->num_uniq);
    }
    return (i64_t)Math_decode_bigend_u64(offsets);
}

#define NULL_SENTINEL -1 

ViewCharBuf*
SortCache_value(SortCache *self, i32_t ord, ViewCharBuf *value)
{
    i64_t offset = SI_fetch_offset(self, ord);
    if (offset == NULL_SENTINEL) { 
        return NULL; 
    }
    else {
        u32_t next_ord = ord + 1;
        i64_t next_offset;
        while (NULL_SENTINEL == (next_offset = SI_fetch_offset(self, next_ord))) {
            next_ord++;
        }
        {
            i64_t  len = next_offset - offset;
            char  *end = self->char_data + next_offset;
            if (end > self->char_data_limit) {
                i64_t over = end - self->char_data_limit;
                THROW("Read %i64 beyond char data limit", over);
            }
            ViewCB_Assign_Str(value, self->char_data + offset, (size_t)len);
        }
    }
    return value;
}

i32_t
SortCache_ordinal(SortCache *self, i32_t doc_id)
{
    if (doc_id > self->doc_max) { 
        THROW("Out of range: %i32 > %i32", doc_id, self->doc_max);
    }
    switch (self->width) {
        case 1: return IntArr_u1get(self->ords, doc_id);
        case 2: return IntArr_u2get(self->ords, doc_id);
        case 4: return IntArr_u4get(self->ords, doc_id);
        case 8: {
            u8_t *ints = (u8_t*)self->ords;
            return ints[doc_id];
        }
        case 16: {
            u16_t *ints = (u16_t*)self->ords;
            return ints[doc_id];
        }
        case 32: {
            u32_t *ints = (u32_t*)self->ords;
            return ints[doc_id];
        }
        default: UNREACHABLE_RETURN(i32_t);
    }
}

i32_t
SortCache_find(SortCache *self, Obj *term)
{
    FieldType *const type = self->type;
    i32_t          lo     = 0;
    i32_t          hi     = self->num_uniq - 1;
    i32_t          result = -100;
    ZombieCharBuf  value  = ZCB_BLANK;

    if ( term != NULL && !OBJ_IS_A(term, CHARBUF)) {
        THROW("term is a %o, and not comparable to a %o",
            Obj_Get_Class_Name(term), CHARBUF.name);
    }

    /* Binary search. */
    while (hi >= lo) {
        const i32_t mid = lo + ((hi - lo) / 2);
        ViewCharBuf *val = SortCache_Value(self, mid, (ViewCharBuf*)&value);
        i64_t comparison = FType_Compare_Values(type, term, (Obj*)val);
        if (comparison < 0) {
            hi = mid - 1;
        }
        else if (comparison > 0) {
            lo = mid + 1;
        }
        else {
            result = mid;
            break;
        }
    }

    if (hi < 0) { 
        /* Target is "less than" the first cache entry. */
        return -1;
    }
    else if (result == -100) {
        /* If result is still -100, it wasn't set. */
        return hi;
    }
    else {
        return result;
    }
}

void*
SortCache_get_ords(SortCache *self)       { return self->ords; }
i32_t
SortCache_get_num_unique(SortCache *self) { return self->num_uniq; }
i32_t
SortCache_get_width(SortCache *self)      { return self->width; }

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

