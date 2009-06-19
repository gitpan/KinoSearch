#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "KinoSearch/Obj.h"
#include "KinoSearch/Obj/VTable.h"
#include "KinoSearch/Util/Err.h"
#include "KinoSearch/Util/CharBuf.h"
#include "KinoSearch/Util/Hash.h"
#include "KinoSearch/Util/MemManager.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"

Obj*
Obj_init(Obj *self)
{
    ABSTRACT_CLASS_CHECK(self, OBJ);
    return self;
}

void
Obj_destroy(Obj *self)
{
    FREE_OBJ(self);
}

i32_t
Obj_hash_code(Obj *self)
{
    return (i32_t)self;
}

bool_t
Obj_is_a(Obj *self, VTable *target_vtable)
{
    VTable *vtable = self ? self->vtable : NULL;

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
Obj_serialize(Obj *self, OutStream *outstream)
{
    CharBuf *class_name = Obj_Get_Class_Name(self);
    CB_Serialize(class_name, outstream);
}

Obj*
Obj_deserialize(Obj *self, InStream *instream)
{
    CharBuf *class_name = CB_deserialize(NULL, instream);
    if (!self) {
        VTable *vtable = VTable_singleton(class_name, (VTable*)&OBJ);
        self = VTable_Make_Obj(vtable);
    }
    else {
        CharBuf *my_class = VTable_Get_Name(self->vtable);
        if (!CB_Equals(class_name, (Obj*)my_class)) 
            THROW("Class mismatch: %o %o", class_name, my_class);
    }
    DECREF(class_name);
    return Obj_init(self);
}

CharBuf*
Obj_to_string(Obj *self)
{
#if (SIZEOF_PTR == 4)
    return CB_newf("%o@0x%x32", Obj_Get_Class_Name(self), self);
#elif (SIZEOF_PTR == 8)
    size_t address = self;
    u32_t  address_hi = address >> 32;
    u32_t  address_lo = address & 0xFFFFFFFF;
    return CB_newf("%o@0x%x32%x32", Obj_Get_Class_Name(self), address_hi,
        address_lo);
#endif
}

Obj*
Obj_dump(Obj *self)
{
    return (Obj*)Obj_To_String(self);
}

VTable*
Obj_get_vtable(Obj *self) { return self->vtable; }
CharBuf*
Obj_get_class_name(Obj *self) { return VTable_Get_Name(self->vtable); }

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

