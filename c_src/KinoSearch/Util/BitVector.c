#include "KinoSearch/Util/ToolSet.h"

#include <math.h>

#define KINO_WANT_BITVECTOR_VTABLE
#include "KinoSearch/Util/BitVector.r"

/* Shared subroutine for performing both OR and XOR ops.
 */
#define DO_OR 1
#define DO_XOR 2
static void
do_or_or_xor(BitVector *self, BitVector *other, int operation);

/* 1 bit per byte.  Use bitwise and to see if a bit is set. 
 */
static const u8_t bitmasks[] = { 
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,
};

/* Clear a bit.  Caller must ensure that num is within capacity.
 */
#define CLEAR(self, num) self->bits[ (num >> 3) ] &= ~(bitmasks[num & 0x7])

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

    /* derive */
    self->bits     = CALLOCATE(byte_size, u8_t);

    /* assign */
    self->cap      = byte_size * 8;
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
    BitVector *evil_twin = BitVec_new(self->cap);
    u32_t byte_size = ceil(self->cap / 8.0);

    /* forbid inheritance */
    if (self->_ != &BITVECTOR)
        CONFESS("Attempt by %s to inherit BitVec_Clone", self->_->class_name);

    memcpy(evil_twin->bits, self->bits, byte_size * sizeof(u8_t));

    return evil_twin;
}

void
BitVec_grow(BitVector *self, u32_t new_max) 
{
    if (new_max >= self->cap) {
        const size_t old_byte_cap  = ceil(self->cap / 8.0); 
        const size_t new_byte_cap  = ceil((new_max + 1) / 8.0); 
        const size_t num_new_bytes = new_byte_cap - old_byte_cap;

        self->bits = REALLOCATE(self->bits, new_byte_cap, u8_t);
        memset(self->bits + old_byte_cap, 0, num_new_bytes);
        self->cap = new_byte_cap * 8;
    }
}

void 
BitVec_set(BitVector *self, u32_t num) 
{
    BITVEC_GROW(self, num);
    self->bits[ (num >> 3) ]  |= bitmasks[num & 0x7];
}

void 
BitVec_clear(BitVector *self, u32_t num) 
{
    if (num >= self->cap) 
        return;
    CLEAR(self, num);
}

bool_t
BitVec_get(const BitVector *self, u32_t num) 
{
    if (num >= self->cap)
        return false;
    return (self->bits[ (num >> 3) ] & bitmasks[num & 0x7]) == 0
        ? false
        : true;
}

void
BitVec_and(BitVector *self, BitVector *other) 
{
    u8_t *bits_a = self->bits;
    u8_t *bits_b = other->bits;
    const u32_t min_cap = self->cap < other->cap 
        ? self->cap 
        : other->cap;
    const size_t byte_size = ceil(min_cap / 8.0);
    u8_t *const limit = bits_a + byte_size;

    /* intersection */
    while (bits_a < limit) {
        *bits_a &= *bits_b;
        bits_a++, bits_b++;
    }

    /* set all remaining to zero */
    if (self->cap > min_cap) {
        const size_t self_byte_size = ceil(self->cap / 8.0);
        memset(bits_a, 0, self_byte_size - byte_size);
    }
}

void
BitVec_or(BitVector *self, BitVector *other) 
{
    do_or_or_xor(self, other, DO_OR);
}

void
BitVec_xor(BitVector *self, BitVector *other) 
{
    do_or_or_xor(self, other, DO_XOR);
}

static void
do_or_or_xor(BitVector *self, BitVector *other, int operation)
{
    u8_t *bits_a, *bits_b;
    u32_t max_cap, min_cap;
    u8_t *limit;
    size_t byte_size;

    /* sort out what the minimum and maximum caps are */
    if (self->cap < other->cap) {
        max_cap = other->cap;
        min_cap = self->cap;
    }
    else {
        max_cap = self->cap;
        min_cap = other->cap;
    }

    /* grow self if smaller than other, then calc pointers */
    BITVEC_GROW(self, max_cap);
    bits_a        = self->bits;
    bits_b        = other->bits;
    byte_size     = ceil(min_cap / 8.0);
    limit         = self->bits + byte_size;

    /* perform union of common bits */
    if (operation == DO_OR) {
        while (bits_a < limit) {
            *bits_a |= *bits_b;
            bits_a++, bits_b++;
        }
    }
    else if (operation == DO_XOR) {
        while (bits_a < limit) {
            *bits_a ^= *bits_b;
            bits_a++, bits_b++;
        }
    }
    else {
        CONFESS("Unrecognized operation: %d", operation);
    }

    /* copy remaining bits if other is bigger than self */
    if (other->cap > min_cap) {
        const size_t other_byte_size = ceil(other->cap / 8.0);
        const size_t bytes_to_copy = other_byte_size - byte_size;
        memcpy(bits_a, bits_b, bytes_to_copy);
    }
}

void
BitVec_and_not(BitVector *self, BitVector *other) 
{
    u8_t *bits_a = self->bits;
    u8_t *bits_b = other->bits;
    const u32_t min_cap = self->cap < other->cap 
        ? self->cap 
        : other->cap;
    const size_t byte_size = ceil(min_cap / 8.0);
    u8_t *const limit = bits_a + byte_size;

    /* clear bits set in other */
    while (bits_a < limit) {
        *bits_a &= ~(*bits_b);
        bits_a++, bits_b++;
    }
}

void
BitVec_flip(BitVector *self, u32_t num) 
{
    const u32_t tick = num >> 3;
    const u8_t single_bit_mask = bitmasks[ (num % 8) ];
    u8_t byte;

    BITVEC_GROW(self, num);
    byte = self->bits[tick];

    if ((byte & single_bit_mask) == single_bit_mask) /* bit is set */
        byte &= ~single_bit_mask; /* turn off one bit */
    else 
        byte |= single_bit_mask; /* turn on one bit */

    self->bits[tick] = byte; 
}

void
BitVec_flip_range(BitVector *self, u32_t from_bit, u32_t to_bit) 
{
    u32_t first = from_bit;
    u32_t last  = to_bit - 1;

    /* proceed only if we have bits to flip */
    if (from_bit == to_bit) 
        return;

    BITVEC_GROW(self, last);

    /* flip partial bytes */
    while (last % 8 != 0 && last > first) {
        BitVec_flip(self, last);
        last--;
    }
    while (first % 8 != 0 && first < last) {
        BitVec_flip(self, first);
        first++;
    }

    /* are first and last equal ? */
    if (first == last) {
        /* there's only one bit left to flip */
        BitVec_flip(self, last);
    }
    /* they must be multiples of 8, then */
    else {
        const u32_t start_tick = first >> 3;
        const u32_t limit_tick = last  >> 3;
        u8_t *bits  = self->bits + start_tick;
        u8_t *limit = self->bits + limit_tick;

        /* last actually belongs to the following byte (e.g. 8, in byte 2) */
        BitVec_flip(self, last);

        /* flip whole bytes */
        while (bits < limit) {
            *bits = ~(*bits);
            bits++;
        }
    }
}

u32_t 
BitVec_count(BitVector *self) 
{
    u32_t count = 0;
    const size_t byte_size = ceil(self->cap / 8.0);
    u8_t *ptr = self->bits;
    u8_t *const limit = ptr + byte_size;

    for( ; ptr < limit; ptr++) {
        count += BYTE_COUNTS[*ptr];
    }

    return count;
}

u32_t*
BitVec_to_array(BitVector *self)
{
    u32_t count             = BitVec_Count(self);
    const u32_t capacity    = self->cap;
    u32_t *const array      = (u32_t *const)MALLOCATE(count, u32_t);
    const size_t byte_size  = ceil(self->cap / 8.0);
    u8_t *const bits        = self->bits;
    u8_t *const limit       = bits + byte_size;
    u32_t num               = 0;
    u32_t i                 = 0;

    while (count--) {
        u8_t *ptr = bits + (num >> 3);
        while (ptr < limit && *ptr == 0) {
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

