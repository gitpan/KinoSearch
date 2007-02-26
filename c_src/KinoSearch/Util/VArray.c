#include <string.h>

#define KINO_USE_SHORT_NAMES

#define KINO_WANT_VARRAY_VTABLE
#include "KinoSearch/Util/VArray.r"

#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/MemManager.h"

#define MAYBE_GROW(_self, _new_size) \
    do { \
        if ((_self)->cap < _new_size) \
            VA_grow(_self, _new_size); \
    } while (0)


VArray*
VA_new(u32_t capacity) 
{
    CREATE(self, VArray, VARRAY);

    /* init */
    self->size = 0;

    /* assign */
    self->cap = capacity;

    /* derive */
    self->elems = CALLOCATE(capacity, Obj*);

    return self;
}

void
VA_destroy(VArray *self) 
{
    Obj **elems        = self->elems;
    Obj **const limit  = elems + self->size;

    /* dispose of elements */
    for ( ; elems < limit; elems++) {
        if (*elems != NULL)
            REFCOUNT_DEC(*elems);
    }

    free(self->elems);
    free(self);
}

void
VA_push(VArray *self, Obj *element) 
{
    MAYBE_GROW(self, self->size + 1);
    self->elems[ self->size ] = element;
    REFCOUNT_INC(element);
    self->size++;
}

Obj*
VA_pop(VArray *self) 
{
    if (!self->size) 
        return NULL;
    self->size--;
    return  self->elems[ self->size ];
}

void
VA_unshift(VArray *self, Obj *elem) 
{
    MAYBE_GROW(self, self->size + 1);
    memmove(self->elems + 1, self->elems, self->size * sizeof(Obj*));
    self->elems[0] = elem;
    REFCOUNT_INC(elem);
    self->size++;
}

Obj*
VA_shift(VArray *self) 
{
    if (!self->size) {
        return NULL;
    }
    else {
        Obj *const return_val = self->elems[0];
        self->size--;
        if (self->size > 0) {
            memmove(self->elems, self->elems + 1, 
                self->size * sizeof(Obj*));
        }
        return return_val;
    }
}

Obj*
VA_fetch(VArray *self, u32_t num) 
{
    if (num >= self->size) 
        return NULL;

    return self->elems[num];
}

void
VA_store(VArray *self, u32_t num, Obj *elem) 
{
    MAYBE_GROW(self, num + 1);
    if (num < self->size) {
        Obj *const old_elem = self->elems[num];
        if (old_elem != NULL)
            REFCOUNT_DEC(old_elem);
    }
    else {
        self->size = num + 1;
    }
    self->elems[num] = elem;
    REFCOUNT_INC(elem);
}

void
VA_grow(VArray *self, u32_t capacity) 
{
    if (capacity > self->cap) {
        self->elems = REALLOCATE(self->elems, capacity, Obj*); 
        self->cap   = capacity;
        memset(self->elems + self->size, 0,
            (capacity - self->size) * sizeof(Obj*));
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

