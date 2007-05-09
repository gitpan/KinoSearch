#ifndef H_KINO_BITVECTOR
#define H_KINO_BITVECTOR 1
 
#include "KinoSearch/Util/Obj.r"

#define KINO_BITVEC_SENTINEL 0xFFFFFFFF

typedef struct kino_BitVector kino_BitVector;
typedef struct KINO_BITVECTOR_VTABLE KINO_BITVECTOR_VTABLE;

KINO_CLASS("KinoSearch::Util::BitVector", "BitVec", "KinoSearch::Util::Obj");

struct kino_BitVector {
    KINO_BITVECTOR_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    chy_u32_t cap;
    chy_u8_t *bits;
    chy_u32_t count;
};

/* Constructor.  All bits are initially zero.
 */
kino_BitVector*
kino_BitVec_new(chy_u32_t capacity);

/* Initialize BitVector members.  Called by subclasses.
 */
void
kino_BitVec_init_base(kino_BitVector *self, chy_u32_t capacity);

/* Return true if the bit indcated by $num has been set, false if it hasn't
 * (regardless of whether $num lies within the bounds of the object's
 * capacity).
 */
chy_bool_t
kino_BitVec_get(const kino_BitVector *self, chy_u32_t num);
KINO_METHOD("Kino_BitVec_Get");

/* Set the bit at [num] to 1.
 */
void 
kino_BitVec_set(kino_BitVector *self, chy_u32_t num);
KINO_METHOD("Kino_BitVec_Set");

/* Clear the bit at [num] (i.e. set it to 0).
 */
void
kino_BitVec_clear(kino_BitVector *self, chy_u32_t num);
KINO_METHOD("Kino_BitVec_Clear");

/* If the BitVector does not already have enough room to hold [capacity] bits,
 * allocate more memory so that it can.
 */
void
kino_BitVec_grow(kino_BitVector *self, chy_u32_t capacity);
KINO_METHOD("Kino_BitVec_Grow");

/* Modify the BitVector so that only bits which remain set are those which 1)
 * were already set in this BitVector, and 2) were also set in the other
 * BitVector.
 */
void
kino_BitVec_and(kino_BitVector *self, kino_BitVector *other);
KINO_METHOD("Kino_BitVec_And");

/* Modify the BitVector, setting all bits which are set in [other] if they
 * were not already set.
 */
void
kino_BitVec_or(kino_BitVector *self, kino_BitVector *other);
KINO_METHOD("Kino_BitVec_Or");

/* Modify the BitVector, performing an XOR operation against [other].
 */
void
kino_BitVec_xor(kino_BitVector *self, kino_BitVector *other);
KINO_METHOD("Kino_BitVec_Xor");

/* Modify the BitVector, clearing all bits from [self] which are set in
 * [other].
 */
void
kino_BitVec_and_not(kino_BitVector *self, kino_BitVector *other);
KINO_METHOD("Kino_BitVec_And_Not");

/* Invert the value of a bit.
 */
void
kino_BitVec_flip(kino_BitVector *self, chy_u32_t num); 
KINO_METHOD("Kino_BitVec_Flip");

/* Invert the values in the BitVector from [from_tick], inclusive, to
 * [to_tick], exclusive.  If [from_tick] and [to_tick] are the same, no
 * change will occur.
 */
void
kino_BitVec_flip_range(kino_BitVector *self, chy_u32_t from_tick, 
                       chy_u32_t to_tick);
KINO_METHOD("Kino_BitVec_Flip_Range");

/* Return a count of the number of set bits.
 */
chy_u32_t 
kino_BitVec_count(kino_BitVector *self);
KINO_METHOD("Kino_BitVec_Count");

/* Return an array where each element represents a set bit.
 */
chy_u32_t*
kino_BitVec_to_array(kino_BitVector *self);
KINO_METHOD("Kino_BitVec_To_Array");

void
kino_BitVec_destroy(kino_BitVector* self);
KINO_METHOD("Kino_BitVec_Destroy");

kino_BitVector*
kino_BitVec_clone(kino_BitVector *self);
KINO_METHOD("Kino_BitVec_Clone");

KINO_END_CLASS

#define KINO_BITVEC_GROW(self, num) \
    do { \
        if (num >= self->cap) \
            Kino_BitVec_Grow(self, num); \
    } while (0)

#ifdef KINO_USE_SHORT_NAMES
  #define BITVEC_GROW(self, num) KINO_BITVEC_GROW(self, num)
#endif

#endif /* H_KINO_BITVECTOR */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

