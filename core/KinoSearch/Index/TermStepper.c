#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/TermStepper.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/StringHelper.h"

TermStepper*
TermStepper_init(TermStepper *self)
{
    Stepper_init((Stepper*)self);
    self->value = NULL;
    return self;
}

void
TermStepper_destroy(TermStepper *self)
{
    DECREF(self->value);
    SUPER_DESTROY(self, TERMSTEPPER);
}

void
TermStepper_reset(TermStepper *self)
{
    DECREF(self->value);
    self->value = NULL;
}

Obj*
TermStepper_get_value(TermStepper *self)
{
    return self->value;
}

void
TermStepper_set_value(TermStepper *self, Obj *value)
{
    DECREF(self->value);
    self->value = value ? INCREF(value) : NULL;
}

void
TermStepper_mimic(TermStepper *self, Obj *other)
{
    TermStepper *evil_twin = (TermStepper*)ASSERT_IS_A(other, TERMSTEPPER);
    Obj_Mimic(self, evil_twin->value);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

