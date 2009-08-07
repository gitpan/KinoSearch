#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Util/I32Array.h"

I32Array*
I32Arr_new(i32_t *ints, u32_t size) 
{
    I32Array *self = (I32Array*)VTable_Make_Obj(I32ARRAY);
    i32_t *ints_copy = MALLOCATE(size, i32_t);
    memcpy(ints_copy, ints, size * sizeof(i32_t));
    return I32Arr_init(self, ints_copy, size);
}

I32Array*
I32Arr_new_steal(i32_t *ints, u32_t size) 
{
    I32Array *self = (I32Array*)VTable_Make_Obj(I32ARRAY);
    return I32Arr_init(self, ints, size);
}

I32Array*
I32Arr_init(I32Array *self, i32_t *ints, u32_t size) 
{
    self->ints = ints;
    self->size = size;
    return self;
}

void
I32Arr_destroy(I32Array *self)
{
    FREEMEM(self->ints);
    FREE_OBJ(self);
}

i32_t 
I32Arr_get(I32Array *self, i32_t num)
{
    if (num < 0 || num >= (i32_t)self->size) {
        THROW(ERR, "Out of bounds: %i32 >= %i32", num, self->size);
    }
    return self->ints[num];
}

u32_t
I32Arr_get_size(I32Array *self) { return self->size; }

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

