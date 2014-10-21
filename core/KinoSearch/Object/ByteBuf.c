#define C_KINO_BYTEBUF
#define C_KINO_VIEWBYTEBUF
#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

#include "KinoSearch/Object/VTable.h"
#include "KinoSearch/Object/ByteBuf.h"
#include "KinoSearch/Object/Err.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/Memory.h"

static void
S_grow(ByteBuf *self, size_t size);

ByteBuf*
BB_new(size_t capacity) 
{
    ByteBuf *self = (ByteBuf*)VTable_Make_Obj(BYTEBUF);
    return BB_init(self, capacity);
}

ByteBuf*
BB_init(ByteBuf *self, size_t capacity)
{
    size_t amount = capacity ? capacity : sizeof(int64_t);
    self->buf   = NULL;
    self->size  = 0;
    self->cap   = 0;
    S_grow(self, amount);
    return self;
}

ByteBuf*
BB_new_bytes(const void *bytes, size_t size) 
{
    ByteBuf *self = (ByteBuf*)VTable_Make_Obj(BYTEBUF);
    BB_init(self, size);
    memcpy(self->buf, bytes, size);
    self->size = size;
    return self;
}

ByteBuf*
BB_new_steal_bytes(void *bytes, size_t size, size_t capacity) 
{
    ByteBuf *self = (ByteBuf*)VTable_Make_Obj(BYTEBUF);
    self->buf  = (char*)bytes;
    self->size = size;
    self->cap  = capacity;
    return self;
}

void 
BB_destroy(ByteBuf *self) 
{
    FREEMEM(self->buf);
    SUPER_DESTROY(self, BYTEBUF);
}

ByteBuf*
BB_clone(ByteBuf *self) 
{
    return BB_new_bytes(self->buf, self->size);
}

void
BB_set_size(ByteBuf *self, size_t size) 
{ 
    if (size > self->cap) {
        THROW(ERR, "Can't set size to %u64 ( greater than capacity of %u64)",
            (uint64_t)size, (uint64_t)self->cap);
    }
    self->size = size; 
}

char*
BB_get_buf(ByteBuf *self)      { return self->buf; }
size_t
BB_get_size(ByteBuf *self)     { return self->size; }
size_t
BB_get_capacity(ByteBuf *self) { return self->cap; }

static INLINE bool_t
SI_equals_bytes(ByteBuf *self, const void *bytes, size_t size)
{
    if (self->size != size) { return false; }
    return (memcmp(self->buf, bytes, self->size) == 0);
}

bool_t
BB_equals(ByteBuf *self, Obj *other)
{
    ByteBuf *const evil_twin = (ByteBuf*)other;
    if (evil_twin == self) return true;
    if (!Obj_Is_A(other, BYTEBUF)) return false;
    return SI_equals_bytes(self, evil_twin->buf, evil_twin->size);
}

bool_t
BB_equals_bytes(ByteBuf *self, const void *bytes, size_t size)
{
    return SI_equals_bytes(self, bytes, size);
}

int32_t
BB_hash_sum(ByteBuf *self)
{
    uint32_t       sum = 5381; 
    uint8_t *const buf = (uint8_t*)self->buf;

    for (size_t i = 0, max = self->size; i < max; i++) {
        sum = ((sum << 5) + sum) ^ buf[i];
    }

    return (int32_t)sum;
}

static INLINE void
SI_mimic_bytes(ByteBuf *self, const void *bytes, size_t size) 
{
    if (size > self->cap) { S_grow(self, size); }
    memmove(self->buf, bytes, size);
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
    ByteBuf *evil_twin = (ByteBuf*)CERTIFY(other, BYTEBUF);
    SI_mimic_bytes(self, evil_twin->buf, evil_twin->size);
}

static INLINE void 
SI_cat_bytes(ByteBuf *self, const void *bytes, size_t size) 
{
    const size_t new_size = self->size + size;
    if (new_size > self->cap) { 
        S_grow(self, Memory_oversize(new_size, sizeof(char))); 
    }
    memcpy((self->buf + self->size), bytes, size);
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
    SI_cat_bytes(self, other->buf, other->size);
}

static void
S_grow(ByteBuf *self, size_t size)
{
    if (size > self->cap) {
        size_t amount    = size;
        size_t remainder = amount % sizeof(int64_t);
        if (remainder) {
            amount += sizeof(int64_t);
            amount -= remainder;
        }
        self->buf = (char*)REALLOCATE(self->buf, amount);
        self->cap = amount;
    }
}

char*
BB_grow(ByteBuf *self, size_t size) 
{
    if (size > self->cap) { S_grow(self, size); }
    return self->buf;
}

void
BB_serialize(ByteBuf *self, OutStream *target)
{
    OutStream_Write_C32(target, self->size);
    OutStream_Write_Bytes(target, self->buf, self->size);
}

ByteBuf*
BB_deserialize(ByteBuf *self, InStream *instream)
{
    const size_t size = InStream_Read_C32(instream);
    const size_t capacity = size ? size : sizeof(int64_t);
    self = self ? self : (ByteBuf*)VTable_Make_Obj(BYTEBUF);
    if (capacity > self->cap) { S_grow(self, capacity); }
    self->size = size;
    InStream_Read_Bytes(instream, self->buf, size);
    return self;
}

int 
BB_compare(const void *va, const void *vb) 
{
    const ByteBuf *a = *(const ByteBuf**)va;
    const ByteBuf *b = *(const ByteBuf**)vb;
    const size_t size = a->size < b->size ? a->size : b->size;

    int32_t comparison = memcmp(a->buf, b->buf, size);

    if (comparison == 0 && a->size != b->size) 
        comparison = a->size < b->size ? -1 : 1;

    return comparison;
}

int32_t
BB_compare_to(ByteBuf *self, Obj *other)
{
    CERTIFY(other, BYTEBUF);
    return BB_compare(&self, &other);
}

/******************************************************************/

ViewByteBuf*
ViewBB_new(char *buf, size_t size) 
{
    ViewByteBuf *self = (ViewByteBuf*)VTable_Make_Obj(VIEWBYTEBUF);
    return ViewBB_init(self, buf, size);
}

ViewByteBuf*
ViewBB_init(ViewByteBuf *self, char *buf, size_t size) 
{
    self->cap  = 0;
    self->buf  = buf;
    self->size = size;
    return self;
}

void 
ViewBB_destroy(ViewByteBuf *self) 
{
    Obj_destroy((Obj*)self);
}

void
ViewBB_assign_bytes(ViewByteBuf *self, char*buf, size_t size) 
{
    self->buf  = buf;
    self->size = size;
}

void
ViewBB_assign(ViewByteBuf *self, const ByteBuf *other)
{
    self->buf  = other->buf;
    self->size = other->size;
}

/* Copyright 2007-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

