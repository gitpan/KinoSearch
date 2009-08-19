#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SortCache/TextSortCache.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/Folder.h"

TextSortCache*
TextSortCache_new(Schema *schema, Folder *folder, Segment *segment, 
              i32_t field_num, i32_t num_unique, i32_t null_ord)
{
    TextSortCache *self = (TextSortCache*)VTable_Make_Obj(TEXTSORTCACHE);
    return TextSortCache_init(self, schema, folder, segment, field_num,
        num_unique, null_ord);
}

TextSortCache*
TextSortCache_init(TextSortCache *self, Schema *schema, Folder *folder,
                   Segment *segment, i32_t field_num, i32_t num_unique,
                   i32_t null_ord)
{
    CharBuf   *field    = Seg_Field_Name(segment, field_num);
    CharBuf   *seg_name = Seg_Get_Name(segment);
    CharBuf   *ord_file = CB_newf("%o/sort-%i32.ord", seg_name, field_num);
    CharBuf   *ix_file  = CB_newf("%o/sort-%i32.ix",  seg_name, field_num);
    CharBuf   *dat_file = CB_newf("%o/sort-%i32.dat", seg_name, field_num);
    FieldType *type     = Schema_Fetch_Type(schema, field);
    i32_t      doc_max  = Seg_Get_Count(segment);
    i64_t ord_len, ix_len, dat_len;
    void *ords;

    /* Validate. */
    if (!type || !FType_Sortable(type)) {
        THROW(ERR, "'%o' isn't a sortable field", field);
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
        Err_throw_mess(ERR, mess);
    }
    ord_len = InStream_Length(self->ord_in);
    ix_len  = InStream_Length(self->ix_in);
    dat_len = InStream_Length(self->dat_in);

    /* Mmap ords, offsets and character data. */
    ords            = InStream_Buf(self->ord_in, (size_t)ord_len);
    self->offsets   = (i64_t*)InStream_Buf(self->ix_in, (size_t)ix_len);
    self->char_data = InStream_Buf(self->dat_in, (size_t)dat_len);
    {
        char *offs            = (char*)self->offsets;
        self->offsets_limit   = (i64_t*)(offs + ix_len);
        self->char_data_limit = self->char_data + dat_len;
    }

    SortCache_init((SortCache*)self, field, type, ords, num_unique, doc_max,
        null_ord);

    /* Validate file lengths. */
    {
        double bytes_per_doc = self->ord_width / 8.0;
        double max_ords      = ord_len / bytes_per_doc;
        if (max_ords < self->doc_max + 1) {
            THROW(ERR, "Conflict between ord count max %f64 and doc_max %i32 for "
                "field %o", max_ords, self->doc_max, field);
        }
    }

    DECREF(ord_file);
    DECREF(ix_file);
    DECREF(dat_file);

    return self;
}

void
TextSortCache_destroy(TextSortCache *self)
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
    SUPER_DESTROY(self, TEXTSORTCACHE);
}

static INLINE i64_t
SI_fetch_offset(TextSortCache *self, u32_t ord)
{
    i64_t *const offsets = self->offsets + ord;
    if (offsets >= self->offsets_limit) {
        THROW(ERR, "Ordinal %u32 for %o out of bounds (num unique: %i32)", ord,
            self->field, self->num_uniq);
    }
    return (i64_t)NumUtil_decode_bigend_u64(offsets);
}

#define NULL_SENTINEL -1 

Obj*
TextSortCache_value(TextSortCache *self, i32_t ord, Obj *blank)
{
    i64_t offset;
    if (ord == self->null_ord) {
        return NULL;
    }
    offset = SI_fetch_offset(self, ord);
    if (offset == NULL_SENTINEL) { 
        return NULL; 
    }
    else {
        u32_t next_ord = ord + 1;
        i64_t next_offset;
        while (1) {
            next_offset = SI_fetch_offset(self, next_ord);
            if (next_offset != NULL_SENTINEL) { break; }
            next_ord++;
        }
        {
            i64_t  len = next_offset - offset;
            char  *end = self->char_data + next_offset;
            if (end > self->char_data_limit) {
                i64_t over = end - self->char_data_limit;
                THROW(ERR, "Read %i64 beyond char data limit for %o", over,
                    self->field);
            }
            ASSERT_IS_A(blank, VIEWCHARBUF);
            ViewCB_Assign_Str(blank, self->char_data + offset, (size_t)len);
        }
    }
    return blank;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

