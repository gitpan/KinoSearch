#define C_KINO_SORTCACHE
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SortCache.h"
#include "KinoSearch/FieldType.h"

static i32_t
S_calc_ord_width(i32_t num_uniq) 
{
    if      (num_uniq <= 0x00000002) { return 1; }
    else if (num_uniq <= 0x00000004) { return 2; }
    else if (num_uniq <= 0x0000000F) { return 4; }
    else if (num_uniq <= 0x000000FF) { return 8; }
    else if (num_uniq <= 0x0000FFFF) { return 16; }
    else                             { return 32; }
}

SortCache*
SortCache_init(SortCache *self, const CharBuf *field, FieldType *type,
               void *ords, i32_t num_unique, i32_t doc_max, i32_t null_ord)
{
    /* Assign. */
    if (!FType_Sortable(type)) { 
        THROW(ERR, "Non-sortable FieldType for %o", field); 
    }
    self->field    = CB_Clone(field);
    self->type     = (FieldType*)INCREF(type);
    self->ords     = ords;
    self->num_uniq = num_unique;
    self->doc_max  = doc_max;
    self->null_ord = null_ord;

    /* Calculate the ord bit width. */
    self->ord_width = S_calc_ord_width(self->num_uniq);

    ABSTRACT_CLASS_CHECK(self, SORTCACHE);
    return self;
}

void
SortCache_destroy(SortCache *self)
{
    DECREF(self->field);
    DECREF(self->type);
    SUPER_DESTROY(self, SORTCACHE);
}

i32_t
SortCache_ordinal(SortCache *self, i32_t doc_id)
{
    if (doc_id > self->doc_max) { 
        THROW(ERR, "Out of range: %i32 > %i32", doc_id, self->doc_max);
    }
    switch (self->ord_width) {
        case 1: return NumUtil_u1get(self->ords, doc_id);
        case 2: return NumUtil_u2get(self->ords, doc_id);
        case 4: return NumUtil_u4get(self->ords, doc_id);
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
        default: {
            THROW(ERR, "Invalid ord width: %i32", self->ord_width);
            UNREACHABLE_RETURN(i32_t);
        }
    }
}

i32_t
SortCache_find(SortCache *self, Obj *term)
{
    FieldType *const type = self->type;
    i32_t          lo     = 0;
    i32_t          hi     = self->num_uniq - 1;
    i32_t          result = -100;
    Obj           *blank  = SortCache_Make_Blank(self);

    if (   term != NULL 
        && !Obj_Is_A(term, Obj_Get_VTable(blank))
        && !Obj_Is_A(blank, Obj_Get_VTable(term))
    ) {
        THROW(ERR, "SortCache error for field %o: term is a %o, and not "
            "comparable to a %o", self->field, Obj_Get_Class_Name(term),
            Obj_Get_Class_Name(blank));
    }

    /* Binary search. */
    while (hi >= lo) {
        const i32_t mid = lo + ((hi - lo) / 2);
        Obj *val = SortCache_Value(self, mid, blank);
        i32_t comparison = FType_Compare_Values(type, term, val);
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

    DECREF(blank);

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

Obj*
SortCache_make_blank(SortCache *self)
{
    return FType_Make_Blank(self->type);
}

void*
SortCache_get_ords(SortCache *self)       { return self->ords; }
i32_t
SortCache_get_num_unique(SortCache *self) { return self->num_uniq; }
i32_t
SortCache_get_ord_width(SortCache *self)  { return self->ord_width; }

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

