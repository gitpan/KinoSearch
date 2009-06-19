#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include "KinoSearch/Util/Float64.h"
#include "KinoSearch/Obj/VTable.h"

Float64*
Float64_new(double value)
{
    Float64 *self = (Float64*)VTable_Make_Obj(&FLOAT64);
    return Float64_init(self, value);
}

Float64*
Float64_init(Float64 *self, double value)
{
    self->value = value;
    return self;
}

bool_t 
Float64_equals(Float64 *self, Obj *other)
{
    Float64 *evil_twin = (Float64*)other;
    if (!OBJ_IS_A(evil_twin, FLOAT64)) return false;
    if (self->value != evil_twin->value) return false;
    return true;
}

double
Float64_get_value(Float64 *self) { return self->value; }
void
Float64_set_value(Float64 *self, double value) { self->value = value; }

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

