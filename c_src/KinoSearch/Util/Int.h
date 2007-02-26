#ifndef H_KINO_INT
#define H_KINO_INT 1

#include "KinoSearch/Util/Obj.r"

/* The main purpose of this class is to serve as an Obj that may be put into
 * VArrays and Hashes.
 */

typedef struct kino_Int kino_Int;
typedef struct KINO_INT_VTABLE KINO_INT_VTABLE;

KINO_CLASS("KinoSearch::Util::Int", "Int", "KinoSearch::Util::Obj");

struct kino_Int {
    KINO_INT_VTABLE *_;
    kino_u32_t refcount;
    kino_i64_t value;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_Int*
kino_Int_new(kino_i64_t value));

KINO_END_CLASS

#endif /* H_KINO_INT */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

