#define C_KINO_UNDEFINED
#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include "KinoSearch/Obj/VTable.h"
#include "KinoSearch/Obj/Undefined.h"

static Undefined the_undef_object = { UNDEFINED, {1} };
Undefined *UNDEF = &the_undef_object;

u32_t
Undefined_get_refcount(Undefined* self)
{
    CHY_UNUSED_VAR(self);
    return 1;
}

Undefined*
Undefined_inc_refcount(Undefined* self)
{
    return self;
}

u32_t
Undefined_dec_refcount(Undefined* self)
{
    UNUSED_VAR(self);
    return 1;
}

/* Copyright 2008-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

