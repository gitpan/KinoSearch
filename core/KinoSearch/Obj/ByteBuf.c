#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

#include "KinoSearch/Obj/VTable.h"
#include "KinoSearch/Obj/ByteBuf.h"

#include "KinoSearch/Obj/Err.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/MemManager.h"
#include "KinoSearch/Util/MathUtils.h"

/* Reallocate if necessary. */
static INLINE void
SI_maybe_grow(ByteBuf *self, size_t capacity);

ByteBuf*
BB_new(size_t capacity) 
{
    ByteBuf *self = (ByteBuf*)VTable_Make_Obj(BYTEBUF);
    return BB_init(self, capacity);
}

ByteBuf*
BB_init(ByteBuf *self, size_t capacity)
{
    size_t amount = capacity ? capacity : sizeof(i64_t);
    self->ptr   = NULL;
    self->size  = 0;
    self->cap   = 0;
    SI_maybe_grow(self, amount);
    return self;
}

ByteBuf*
BB_new_bytes(const void *bytes, size_t size) 
{
    ByteBuf *self = (ByteBuf*)VTable_Make_Obj(BYTEBUF);
    BB_init(self, size);
    memcpy(self->ptr, bytes, size);
    self->size = size;
    return self;
}

ByteBuf*
BB_new_steal_bytes(void *bytes, size_t size, size_t capacity) 
{
    ByteBuf *self = (ByteBuf*)VTable_Make_Obj(BYTEBUF);
    self->ptr  = bytes;
    self->size = size;
    self->cap  = capacity;
    return self;
}

void 
BB_destroy(ByteBuf *self) 
{
    FREEMEM(self->ptr);
    FREE_OBJ(self);
}

ByteBuf*
BB_clone(ByteBuf *self) 
{
    return BB_new_bytes(self->ptr, self->size);
}

void
BB_set_size(ByteBuf *self, size_t size) 
{ 
    if (size > self->cap) {
        THROW(ERR, "Can't set size to %u64 ( greater than capacity of %u64)",
            (u64_t)size, (u64_t)self->cap);
    }
    self->size = size; 
}

size_t
BB_get_size(ByteBuf *self)     { return self->size; }
size_t
BB_get_capacity(ByteBuf *self) { return self->cap; }

static INLINE bool_t
SI_equals_bytes(ByteBuf *self, const void *bytes, size_t size)
{
    if (self->size != size) { return false; }
    return (memcmp(self->ptr, bytes, self->size) == 0);
}

bool_t
BB_equals(ByteBuf *self, Obj *other)
{
    ByteBuf *const evil_twin = (ByteBuf*)other;
    if (evil_twin == self) return true;
    if (!OBJ_IS_A(evil_twin, BYTEBUF)) return false;
    return SI_equals_bytes(self, evil_twin->ptr, evil_twin->size);
}

bool_t
BB_equals_bytes(ByteBuf *self, const void *bytes, size_t size)
{
    return SI_equals_bytes(self, bytes, size);
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

static INLINE void
SI_mimic_bytes(ByteBuf *self, const void *bytes, size_t size) 
{
    SI_maybe_grow(self, size);
    memmove(self->ptr, bytes, size);
    self->size = size;
}

void
BB_mimic_bytes(ByteBuf *self, const void *bytes, size_t size) 
{
    SI_mimic_bytes(self, bytes, size);
}

void
BB_mimic(ByteBuf *self, Obj *other)
{
    ByteBuf *evil_twin = (ByteBuf*)ASSERT_IS_A(other, BYTEBUF);
    SI_mimic_bytes(self, evil_twin->ptr, evil_twin->size);
}

static INLINE void 
SI_cat_bytes(ByteBuf *self, const void *bytes, size_t size) 
{
    const size_t new_size = self->size + size;
    SI_maybe_grow(self, new_size);
    memcpy((self->ptr + self->size), bytes, size);
    self->size = new_size;
}

void 
BB_cat_bytes(ByteBuf *self, const void *bytes, size_t size) 
{
    SI_cat_bytes(self, bytes, size);
}

void 
BB_cat(ByteBuf *self, const ByteBuf *other) 
{
    SI_cat_bytes(self, other->ptr, other->size);
}

u32_t
BB_i32_size(ByteBuf *self)
{
    return (u32_t)(self->size / sizeof(i32_t));
}

i32_t
BB_i32_get(ByteBuf *self, u32_t tick)
{
    size_t  max  = self->size / sizeof(i32_t);
    i32_t  *ints = (i32_t*)self->ptr;
    if (tick >= max) { 
        THROW(ERR, "Out of bounds (%u32 >= %u32)", tick, max);
    }
    return ints[tick];
}

static void
S_grow(ByteBuf *self, size_t capacity)
{
    size_t bleedover = capacity % sizeof(i64_t);
    size_t amount    = capacity + sizeof(i64_t) - bleedover;
    self->ptr = REALLOCATE(self->ptr, amount, char);
    self->cap = amount;
}

static INLINE void
SI_maybe_grow(ByteBuf *self, size_t capacity) 
{
    /* Reallocate only if necessary. */
    if (self->cap < capacity) { S_grow(self, capacity); }
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
    const size_t size = InStream_Read_C32(instream);
    const size_t amount = size ? size : sizeof(i64_t);
    self = self ? self : (ByteBuf*)VTable_Make_Obj(BYTEBUF);
    self->cap  = 0; 
    self->size = 0;
    self->ptr  = NULL;
    SI_maybe_grow(self, amount);
    self->size = size;
    InStream_Read_Bytes(instream, self->ptr, size);
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
    ViewByteBuf *self = (ViewByteBuf*)VTable_Make_Obj(VIEWBYTEBUF);

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
ViewBB_assign_bytes(ViewByteBuf *self, char*ptr, size_t size) 
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

