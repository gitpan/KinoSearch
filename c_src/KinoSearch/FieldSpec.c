#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_FIELDSPEC_VTABLE
#include "KinoSearch/FieldSpec.r"

#include "KinoSearch/Posting.r"

FieldSpec*
FSpec_new(const char *class_name)
{
    CREATE_SUBCLASS(self, class_name, FieldSpec, FIELDSPEC);

    /* set everything to 0, so errors get detected */
    self->boost              = 0.0;
    self->indexed            = false;
    self->stored             = false;
    self->analyzed           = false;
    self->vectorized         = false;
    self->binary             = false;
    self->compressed         = false;
    self->posting            = NULL;

    return self;
}

void
FSpec_destroy(FieldSpec *self)
{
    REFCOUNT_DEC(self->posting);
    free(self);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

