#ifndef H_KINO_INTMAP
#define H_KINO_INTMAP 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_IntMap kino_IntMap;
typedef struct KINO_INTMAP_VTABLE KINO_INTMAP_VTABLE;

KINO_CLASS("KinoSearch::Util::IntMap", "IntMap", "KinoSearch::Util::Obj");

struct kino_IntMap {
    KINO_INTMAP_VTABLE *_;
    kino_u32_t refcount;
    kino_i32_t *ints;
    kino_i32_t size;
};

/* Return the number present at the index requested.  If the requested index 
 * is out of range, return -1.
 */
KINO_METHOD("Kino_IntMap_Get",
kino_i32_t 
kino_IntMap_get(kino_IntMap *self, kino_i32_t num));

/* Constructor.
 */
KINO_FUNCTION(
kino_IntMap*
kino_IntMap_new(kino_i32_t *ints, kino_i32_t size));

KINO_METHOD("Kino_IntMap_Destroy",
void
kino_IntMap_destroy(kino_IntMap *self));

KINO_END_CLASS

#endif /* H_KINO_INTMAP */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

