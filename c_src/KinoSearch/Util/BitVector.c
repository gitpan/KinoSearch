#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#include <math.h>

#define KINO_WANT_BITVECTOR_VTABLE
#include "KinoSearch/Util/BitVector.r"

/* 1 bit per byte.  Use bitwise and to see if a bit is set. 
 */
static const u8_t bitmasks[] = { 
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,
};

/* Number of 1 bits given a u8 value. 
 */
static const u32_t BYTE_COUNTS[256] = {
    0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
    3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
    1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
    3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
    2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
    3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
    3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
    4, 5, 5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8
};


BitVector*
BitVec_new(u32_t capacity) 
{
    CREATE(self, BitVector, BITVECTOR);
    BitVec_init_base(self, capacity);
    return self;
}

void
BitVec_init_base(BitVector *self, u32_t capacity)
{
    const u32_t byte_size = ceil(capacity / 8.0);

    /* init */
    self->count            = 0;
    self->count_is_valid   = false;

    /* derive */
    self->bits     = CALLOCATE(byte_size, u8_t);

    /* assign */
    self->capacity = capacity;
}

void
BitVec_destroy(BitVector* self) 
{
    free(self->bits);
    free(self);
}

BitVector*
BitVec_clone(BitVector *self) 
{
    BitVector *evil_twin = BitVec_new(self->capacity);
    u32_t byte_size = ceil(self->capacity / 8.0);

    memcpy(evil_twin->bits, self->bits, byte_size * sizeof(u8_t));

    return evil_twin;
}

void
BitVec_grow(BitVector *self, u32_t capacity) 
{
    const u32_t old_byte_size = ceil(self->capacity / 8.0);
    const u32_t new_byte_size = ceil(capacity / 8.0);

    if (new_byte_size > old_byte_size && self->bits != NULL) {
        self->bits = REALLOCATE(self->bits, new_byte_size, u8_t);

        /* zero out new bytes, since REALLOCATE doesn't guarantee zeroes */
        memset( (self->bits + old_byte_size), 0x00, 
            (new_byte_size - old_byte_size) );
    }
    else if (self->bits == NULL && capacity > 0) {
        self->bits = CALLOCATE(new_byte_size, u8_t);
    }

    self->capacity = capacity;
}


void 
BitVec_set(BitVector *self, u32_t num) 
{
    if (num >= self->capacity)
        BitVec_Grow(self, num + 1);
    self->bits[ (num >> 3) ]  |= bitmasks[num & 0x7];
    self->count_is_valid = false;
}

void 
BitVec_clear(BitVector *self, u32_t num) 
{
    if (num >= self->capacity) 
        return;
    self->bits[ (num >> 3) ] &= ~(bitmasks[num & 0x7]);
    self->count_is_valid = false;
}

bool_t
BitVec_get(const BitVector *self, u32_t num) 
{
    if (num >= self->capacity)
        return false;
    return (self->bits[ (num >> 3) ] & bitmasks[num & 0x7]) == 0
        ? false
        : true;
}

void
BitVec_logical_and(BitVector *self, BitVector *other) 
{
    u8_t *bits_a = self->bits;
    u8_t *bits_b = other->bits;
    const u32_t min_cap = self->capacity < other->capacity 
        ? self->capacity 
        : other->capacity;
    const size_t byte_size = ceil(min_cap / 8.0);
    u8_t *const limit = bits_a + byte_size;

    /* intersection */
    while (bits_a < limit) {
        *bits_a = (*bits_a & *bits_b);
        bits_a++, bits_b++;
    }

    /* set all remaining to zero */
    if (self->capacity > min_cap) {
        const size_t self_byte_size = ceil(self->capacity / 8.0);
        memset(bits_a, 0, self_byte_size - byte_size);
    }

    self->count_is_valid = false;
}

u32_t 
BitVec_count(BitVector *self) 
{
    if (!self->count_is_valid) {
        u32_t cnt = 0;
        const size_t byte_size = ceil(self->capacity / 8.0);
        u8_t *ptr = self->bits;
        u8_t *const limit = ptr + byte_size;

        for( ; ptr < limit; ptr++) {
            cnt += BYTE_COUNTS[*ptr];
        }

        self->count = cnt;
        self->count_is_valid = true;
    }

    return self->count;
}

u32_t*
BitVec_to_array(BitVector *self)
{
    u32_t count             = BitVec_Count(self);
    const u32_t capacity    = self->capacity;
    u32_t *const array      = (u32_t *const)MALLOCATE(count, u32_t);
    const size_t byte_size  = ceil(self->capacity / 8.0);
    u8_t *const bits        = self->bits;
    u8_t *const limit       = bits + byte_size;
    u32_t num               = 0;
    u32_t i                 = 0;

    while (count--) {
        u8_t *ptr = bits + (num >> 3);
        while (*ptr == 0 && ptr < limit) {
            num += 8;
            ptr++;
        }
        do {
            if (num >= capacity)
                break;
            if (BitVec_Get(self, num))
                array[i++] = num;
        } while (++num % 8);
    }

    return array;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

