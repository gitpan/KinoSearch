#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

#include "KinoSearch/Obj/VTable.h"
#include "KinoSearch/Util/ByteBuf.h"

#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/Err.h"
#include "KinoSearch/Util/MemManager.h"
#include "KinoSearch/Util/MathUtils.h"

/* Reallocate if necessary. */
static INLINE void
SI_maybe_grow(ByteBuf *self, size_t capacity);

ByteBuf*
BB_new(size_t capacity) 
{
    ByteBuf *self = (ByteBuf*)VTable_Make_Obj(&BYTEBUF);
    return BB_init(self, capacity);
}

ByteBuf*
BB_init(ByteBuf *self, size_t capacity)
{
    self->ptr   = MALLOCATE(capacity, char);
    self->size  = 0;
    self->cap   = capacity;
    return self;
}

ByteBuf*
BB_new_str(const char *ptr, size_t size) 
{
    ByteBuf *self = (ByteBuf*)VTable_Make_Obj(&BYTEBUF);
    BB_init(self, size);
    memcpy(self->ptr, ptr, size);
    self->size = size;
    return self;
}

ByteBuf*
BB_new_steal_str(char *ptr, size_t size, size_t capacity) 
{
    ByteBuf *self = (ByteBuf*)VTable_Make_Obj(&BYTEBUF);
    self->ptr  = ptr;
    self->size = size;
    self->cap  = capacity;
    return self;
}

void 
BB_destroy(ByteBuf *self) 
{
    free(self->ptr);
    FREE_OBJ(self);
}

ByteBuf*
BB_clone(ByteBuf *self) 
{
    return BB_new_str(self->ptr, self->size);
}

void
BB_set_size(ByteBuf *self, size_t size) 
{ 
    if (size > self->cap) {
        THROW("Can't set size to %u64 ( greater than capacity of %u64)",
            (u64_t)size, (u64_t)self->cap);
    }
    self->size = size; 
}

size_t
BB_get_size(ByteBuf *self)     { return self->size; }
size_t
BB_get_capacity(ByteBuf *self) { return self->cap; }

bool_t
BB_equals(ByteBuf *self, Obj *other)
{
    ByteBuf *const evil_twin = (ByteBuf*)other;
    if (evil_twin == self) return true;
    if (!OBJ_IS_A(evil_twin, BYTEBUF)) return false;
    return BB_equals_str(self, evil_twin->ptr, evil_twin->size);
}

bool_t
BB_equals_str(ByteBuf *self, const char *ptr, size_t size)
{
    if (self->size != size) { return false; }
    return (memcmp(self->ptr, ptr, self->size) == 0);
}

i32_t
BB_hash_code(ByteBuf *self)
{
    size_t size = self->size; 
    const u8_t *ptr = (const u8_t*)self->ptr; 
    u32_t hashvalue = 0; 

    while (size--) { 
        hashvalue += *ptr++; 
        hashvalue += (hashvalue << 10); 
        hashvalue ^= (hashvalue >> 6); 
    } 
    hashvalue += (hashvalue << 3); 
    hashvalue ^= (hashvalue >> 11); 
    hashvalue += (hashvalue << 15); 

    return (i32_t) hashvalue;
}

void
BB_copy_str(ByteBuf *self, const char* ptr, size_t size) 
{
    SI_maybe_grow(self, size);
    memcpy(self->ptr, ptr, size);
    self->size = size;
}

void
BB_copy(ByteBuf *self, const ByteBuf *other)
{
    SI_maybe_grow(self, other->size);
    memcpy(self->ptr, other->ptr, other->size);
    self->size = other->size;
}

void 
BB_cat_str(ByteBuf *self, const char* ptr, size_t size) 
{
    const size_t new_size = self->size + size;
    SI_maybe_grow(self, new_size);
    memcpy((self->ptr + self->size), ptr, size);
    self->size = new_size;
}

void 
BB_cat(ByteBuf *self, const ByteBuf *other) 
{
    BB_cat_str(self, other->ptr, other->size);
}

static INLINE void
SI_maybe_grow(ByteBuf *self, size_t capacity) 
{
    /* Reallocate only if necessary. */
    if (self->cap >= capacity) { return; }
    self->ptr = REALLOCATE(self->ptr, capacity, char);
    self->cap = capacity;
}

void 
BB_grow(ByteBuf *self, size_t capacity) 
{
    SI_maybe_grow(self, capacity);
}

void
BB_serialize(ByteBuf *self, OutStream *target)
{
    OutStream_Write_C32(target, self->size);
    OutStream_Write_Bytes(target, self->ptr, self->size);
}

ByteBuf*
BB_deserialize(ByteBuf *self, InStream *instream)
{
    self = self ? self : (ByteBuf*)VTable_Make_Obj(&BYTEBUF);
    self->size = InStream_Read_C32(instream);
    self->cap  = self->size;
    self->ptr = MALLOCATE(self->cap, char);
    InStream_Read_Bytes(instream, self->ptr, self->size);
    return self;
}

int 
BB_compare(const void *va, const void *vb) 
{
    const ByteBuf *a = *(const ByteBuf**)va;
    const ByteBuf *b = *(const ByteBuf**)vb;
    const size_t size = a->size < b->size ? a->size : b->size;

    i32_t comparison = memcmp(a->ptr, b->ptr, size);

    if (comparison == 0 && a->size != b->size) 
        comparison = a->size < b->size ? -1 : 1;

    return comparison;
}

/******************************************************************/

ViewByteBuf*
ViewBB_new(char *ptr, size_t size) 
{
    ViewByteBuf *self = (ViewByteBuf*)VTable_Make_Obj(&VIEWBYTEBUF);

    /* Init. */
    self->cap = 0;

    /* Assign. */
    self->ptr  = ptr;
    self->size = size;
    
    return self;
}

void 
ViewBB_destroy(ViewByteBuf *self) 
{
    Obj_destroy((Obj*)self);
}

void
ViewBB_assign_str(ViewByteBuf *self, char*ptr, size_t size) 
{
    self->ptr  = ptr;
    self->size = size;
}

void
ViewBB_assign(ViewByteBuf *self, const ByteBuf *other)
{
    self->ptr  = other->ptr;
    self->size = other->size;
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

