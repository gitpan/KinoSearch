#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_INTMAP_VTABLE
#include "KinoSearch/Util/IntMap.r"

IntMap*
IntMap_new(i32_t *ints, i32_t size) 
{
    CREATE(self, IntMap, INTMAP);
    self->ints = ints;
    self->size = size;
    return self;
}

i32_t 
IntMap_get(IntMap *self, i32_t num)
{
    if (num >= self->size || num < 0) {
        return -1;
    }
    return self->ints[num];
}

void
IntMap_destroy(IntMap *self)
{
    free(self->ints);
    free(self);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

