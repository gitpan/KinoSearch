#ifndef H_KINO_VARRAY
#define H_KINO_VARRAY 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_VArray kino_VArray;
typedef struct KINO_VARRAY_VTABLE KINO_VARRAY_VTABLE;

KINO_CLASS("KinoSearch::Util::VArray", "VA", "KinoSearch::Util::Obj");

struct kino_VArray {
    KINO_VARRAY_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    kino_Obj   **elems;
    kino_u32_t   size;
    kino_u32_t   cap;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_VArray*
kino_VA_new(kino_u32_t capacity));

/* Push an item onto the end of a VArray.
 */
KINO_METHOD("Kino_VA_Push",
void
kino_VA_push(kino_VArray *self, kino_Obj *element));

/* Pop an item off of the end of a VArray.
 */
KINO_METHOD("Kino_VA_Pop",
kino_Obj*
kino_VA_pop(kino_VArray *self));

/* Unshift an item onto the front of a VArray.
 */
KINO_METHOD("Kino_VA_Unshift",
void
kino_VA_unshift(kino_VArray *self, kino_Obj *element));

/* Shift an item off of the front of a VArray.
 */
KINO_METHOD("Kino_VA_Shift",
kino_Obj*
kino_VA_shift(kino_VArray *self));

/* Ensure that the VArray has room for at least [capacity] elements.
 */
KINO_METHOD("Kino_VA_Grow",
void
kino_VA_grow(kino_VArray *self, kino_u32_t capacity));

/* Fetch the element at index [num].
 */
KINO_METHOD("Kino_VA_Fetch",
kino_Obj*
kino_VA_fetch(kino_VArray *self, kino_u32_t num));

/* Store an element at index [num].  Any existing element will have its
 * refcount decremented.
 */
KINO_METHOD("Kino_VA_Store",
void
kino_VA_store(kino_VArray *self, kino_u32_t num, kino_Obj *elem));

KINO_METHOD("Kino_VA_Destroy",
void
kino_VA_destroy(kino_VArray *self));

KINO_END_CLASS

#endif /* H_KINO_VARRAY */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

