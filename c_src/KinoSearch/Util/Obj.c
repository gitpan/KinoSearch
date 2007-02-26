#define KINO_USE_SHORT_NAMES

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define KINO_WANT_OBJ_VTABLE
#include "KinoSearch/Util/Obj.r"

#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/MemManager.h"

Obj*
Obj_new()
{
    CREATE(self, Obj, OBJ);
    return self;
}

void
Obj_destroy(Obj *self)
{
    free(self);
}

#if (KINO_SIZEOF_PTR == 4)
  #define SPACE_FOR_MEMHEX sizeof("0xFFFFFFFF")
#elif (KINO_SIZEOF_PTR == 8)
  #define SPACE_FOR_MEMHEX sizeof("0xFFFFFFFFFFFFFFFF")
#endif

struct kino_ByteBuf;

extern struct kino_ByteBuf*
kino_BB_new_steal(char *ptr, size_t len, size_t cap);

struct kino_ByteBuf*
Obj_to_string(Obj *self)
{
    const size_t class_name_len = strlen(self->_->class_name);
    const size_t cap = class_name_len + SPACE_FOR_MEMHEX + 1;
    char *const ptr = MALLOCATE(cap, char);
    sprintf(ptr, "%s@%#x", self->_->class_name, (unsigned)self);
    return kino_BB_new_steal(ptr, strlen(ptr), cap);
}

i32_t
Obj_hash_code(Obj *self)
{
    return (i32_t)self;
}

Obj*
Obj_clone(Obj *self)
{
    (void)self;
    CONFESS("Obj_Clone is an abstract method");
    return (Obj*)0;
}

bool_t
Obj_is_a(Obj *self, KINO_OBJ_VTABLE *target_vtable)
{
    KINO_OBJ_VTABLE *vtable = self->_;

    while (vtable != NULL) {
        if (vtable == target_vtable)
            return true;
        vtable = vtable->parent;
    }

    return false;
}

bool_t
Obj_equals(Obj *self, Obj *other)
{
    return (self == other);
}

void
Obj_serialize(Obj *self, struct kino_ByteBuf *target)
{
    UNUSED_VAR(self);
    UNUSED_VAR(target);
    CONFESS("Obj_Serialize is an abstract method not implemented in %s",
        self->_->class_name);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

