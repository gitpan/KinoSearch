#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_FIELDSPEC_VTABLE
#include "KinoSearch/Schema/FieldSpec.r"


FieldSpec*
FSpec_new(const char *class_name, const ByteBuf *field_name)
{
    CREATE_SUBCLASS(self, class_name, FieldSpec, FIELDSPEC);

    /* assign */
    self->name         = BB_CLONE(field_name);

    /* set everything to 0, so errors get detected */
    self->boost              = 0.0;
    self->indexed            = false;
    self->stored             = false;
    self->analyzed           = false;
    self->vectorized         = false;
    self->binary             = false;
    self->compressed         = false;
    self->store_field_boost  = false;
    self->store_freq         = false;
    self->store_position     = false;
    self->store_pos_boost    = false;

    return self;
}

void
FSpec_destroy(FieldSpec *self)
{
    REFCOUNT_DEC(self->name);
    free(self);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

