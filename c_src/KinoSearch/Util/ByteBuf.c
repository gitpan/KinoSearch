#define KINO_USE_SHORT_NAMES

#include <string.h>
#include <stdio.h>
#include <ctype.h>

#define KINO_WANT_BYTEBUF_VTABLE
#include "KinoSearch/Util/ByteBuf.r"

#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/MemManager.h"
#include "KinoSearch/Util/MathUtils.h"

/* Maximum number of characters in a stringified 64-bit integer, including
 * minus sign if negative.
 */
#define MAX_I64_CHARS 20

ByteBuf*
BB_to_string(ByteBuf *self)
{
    REFCOUNT_INC(self);
    return self;
}

ByteBuf*
BB_new(size_t future_size) 
{
    CREATE(self, ByteBuf, BYTEBUF);

    /* derive */
    self->ptr = MALLOCATE(future_size + 1, char);

     /* init */
    *self->ptr = '\0';
 
    /* assign */
    self->len   = 0;
    self->cap   = future_size + 1;

    return self;
}

ByteBuf*
BB_new_str(const char *ptr, size_t len) 
{
    CREATE(self, ByteBuf, BYTEBUF);

    /* derive */
    self->ptr = MALLOCATE(len + 1, char);

    /* copy */
    memcpy(self->ptr, ptr, len);

    /* assign */
    self->len       = len;
    self->cap       = len + 1; 
    self->ptr[len] = '\0'; /* null terminate */
    
    return self;
}

ByteBuf*
BB_new_steal(char *ptr, size_t len, size_t cap) 
{
    CREATE(self, ByteBuf, BYTEBUF);

    /* assign the passed in values */
    self->ptr = ptr;
    self->len = len;
    self->cap = cap;

    return self;
}

ByteBuf*
BB_new_i64(i64_t num) {
    CREATE(self, ByteBuf, BYTEBUF);

    self->ptr = MALLOCATE(MAX_I64_CHARS + 1, char);
    self->cap = MAX_I64_CHARS + 1;

    self->len = sprintf(self->ptr, "%"I64P, num);

    return self;
}

ByteBuf*
BB_clone(ByteBuf *self) 
{
    return BB_new_str(self->ptr, self->len);
}

bool_t
BB_equals(ByteBuf *self, ByteBuf *other)
{
    if (self->len != other->len)
        return false;
    return (memcmp(self->ptr, other->ptr, self->len) == 0);
}

i32_t
BB_hash_code(ByteBuf *self)
{
    size_t len = self->len; 
    const u8_t *ptr = (const u8_t*)self->ptr; 
    u32_t hashvalue = 0; 

    while (len--) { 
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
BB_copy_str(ByteBuf *self, char* ptr, size_t len) 
{
    BB_Grow(self, len);
    memcpy(self->ptr, ptr, len);
    self->len = len;
    self->ptr[len] = '\0';
}

void
BB_copy_bb(ByteBuf *self, const ByteBuf *other)
{
    BB_Grow(self, other->len);
    memcpy(self->ptr, other->ptr, other->len);
    self->len = other->len;
    self->ptr[other->len] = '\0';
}

void 
BB_cat_str(ByteBuf *self, char* ptr, size_t len) 
{
    const size_t new_len = self->len + len;
    BB_Grow(self, new_len);
    memcpy((self->ptr + self->len), ptr, len);
    self->len = new_len;
    self->ptr[new_len] = '\0';
}

void 
BB_cat_bb(ByteBuf *self, const ByteBuf *other) 
{
    const size_t new_len = self->len + other->len;
    BB_Grow(self, new_len);
    memcpy((self->ptr + self->len), other->ptr, other->len);
    self->len = new_len;
    self->ptr[new_len] = '\0';
}

void
BB_cat_i64(ByteBuf *self, i64_t num)
{
    BB_Grow(self, self->len + MAX_I64_CHARS);
    self->len += sprintf(BBEND(self), "%"I64P, num);
}

i64_t
BB_to_i64(ByteBuf *self) 
{
    char *ptr   = self->ptr;
    const i64_t NUM_CHAR_OFFSET = '0';
    i64_t retval = 0;
    bool_t is_negative = false;

    /* advance past minus sign */
    if (*ptr == '-') { 
        ptr++;
        is_negative = true;
    }

    for( ; isdigit(*ptr); ptr++) {
        retval *= 10;
        retval += *ptr - NUM_CHAR_OFFSET;
    }
    if (is_negative)
        retval = 0 - retval;

    return retval;
}

void 
BB_grow(ByteBuf *self, size_t new_len) 
{
    /* bail out if the buffer's already at least as big as required */
    if (self->cap > new_len)
        return;

    self->ptr = REALLOCATE(self->ptr, (new_len + 1), char);
    self->cap = new_len + 1;
}

void
BB_serialize(ByteBuf *self, ByteBuf *target)
{
    size_t new_size = target->len + self->len + sizeof(u32_t);

    /* header u32_t length, followed by content */
    BB_Grow(target, new_size);
    Math_encode_bigend_u32(self->len, BBEND(target));
    target->len += sizeof(u32_t);
    memcpy(BBEND(target), self->ptr, self->len + 1);
    target->len += self->len;
}

ByteBuf*
BB_deserialize(struct kino_ViewByteBuf *serialized_vbb)
{
    ByteBuf *const serialized_bb = (ByteBuf*)serialized_vbb;
    u32_t size = Math_decode_bigend_u32(serialized_bb->ptr);
    ByteBuf *self = BB_new(size);

    /* copy string after verifying no invalid memory reads */
    if (serialized_bb->len < size + sizeof(u32_t)) {
        CONFESS("Not enough characters in serialized object: %u %u", size,
            serialized_bb->len);
    }
    BB_Copy_Str(self, serialized_bb->ptr + sizeof(u32_t), size);

    /* consume characters */
    serialized_bb->ptr += size + sizeof(u32_t);
    serialized_bb->len -= (size + sizeof(u32_t));

    return self;
}

void 
BB_destroy(ByteBuf *self) 
{
    free(self->ptr);
    free(self);
}

int 
BB_compare(const void *va, const void *vb) 
{
    const ByteBuf *a = *(const ByteBuf**)va;
    const ByteBuf *b = *(const ByteBuf**)vb;
    const size_t len = a->len < b->len ? a->len : b->len;

    i32_t comparison = memcmp(a->ptr, b->ptr, len);

    if (comparison == 0 && a->len != b->len) 
        comparison = a->len < b->len ? -1 : 1;

    return comparison;
}

kino_bool_t
BB_less_than(const void *va, const void *vb)
{
    const ByteBuf *a = *(const ByteBuf**)va;
    const ByteBuf *b = *(const ByteBuf**)vb;
    const size_t len = a->len < b->len ? a->len : b->len;
    int comparison = memcmp(a->ptr, b->ptr, len); 
    
    if (comparison == 0)
        comparison = a->len - b->len;

    return comparison < 0;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

