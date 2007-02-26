#ifndef H_KINO_BITVECTOR
#define H_KINO_BITVECTOR 1
 
#include "KinoSearch/Util/Obj.r"

#define KINO_BITVEC_SENTINEL 0xFFFFFFFF

typedef struct kino_BitVector kino_BitVector;
typedef struct KINO_BITVECTOR_VTABLE KINO_BITVECTOR_VTABLE;

KINO_CLASS("KinoSearch::Util::BitVector", "BitVec", "KinoSearch::Util::Obj");

struct kino_BitVector {
    KINO_BITVECTOR_VTABLE *_;
    kino_u32_t refcount;
    kino_u32_t capacity;
    kino_u8_t *bits;
    kino_u32_t count;
    kino_bool_t count_is_valid;
};

/* Constructor.  All bits are initially zero.
 */
KINO_FUNCTION(
kino_BitVector*
kino_BitVec_new(kino_u32_t capacity));

/* Initialize BitVector members.  Called by subclasses.
 */
KINO_FUNCTION(
void
kino_BitVec_init_base(kino_BitVector *self, kino_u32_t capacity));

/* Return true if the bit indcated by $num has been set, false if it hasn't
 * (regardless of whether $num lies within the bounds of the object's
 * capacity).
 */
KINO_METHOD("Kino_BitVec_Get",
kino_bool_t
kino_BitVec_get(const kino_BitVector *self, kino_u32_t num));

/* Set the bit at [num] to 1.
 */
KINO_METHOD("Kino_BitVec_Set",
void 
kino_BitVec_set(kino_BitVector *self, kino_u32_t num));

/* Clear the bit at [num] (i.e. set it to 0).
 */
KINO_METHOD("Kino_BitVec_Clear",
void
kino_BitVec_clear(kino_BitVector *self, kino_u32_t num));

/* If the BitVector does not already have enough room to hold [capacity] bits,
 * allocate more memory so that it can.
 */
KINO_METHOD("Kino_BitVec_Grow",
void
kino_BitVec_grow(kino_BitVector *self, kino_u32_t capacity));

/* Modify the BitVector so that only bits which remain set are those which 1)
 * were already set in this BitVector, and 2) were also set in the other
 * BitVector.
 */
KINO_METHOD("Kino_BitVec_Logical_And",
void
kino_BitVec_logical_and(kino_BitVector *self, kino_BitVector *other));

/* Return a count of the number of set bits.
 */
KINO_METHOD("Kino_BitVec_Count",
kino_u32_t 
kino_BitVec_count(kino_BitVector *self));

/* Return an array where each element represents a set bit.
 */
KINO_METHOD("Kino_BitVec_To_Array",
kino_u32_t*
kino_BitVec_to_array(kino_BitVector *self));

KINO_METHOD("Kino_BitVec_Destroy",
void
kino_BitVec_destroy(kino_BitVector* self));

KINO_METHOD("Kino_BitVec_Clone",
kino_BitVector*
kino_BitVec_clone(kino_BitVector *self));

KINO_END_CLASS

#endif /* H_KINO_BITVECTOR */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

