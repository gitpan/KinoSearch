#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TALLY_VTABLE
#include "KinoSearch/Search/Tally.r"

Tally*
Tally_new()
{
    CREATE(self, Tally, TALLY);

    self->score           = 0.0f;
    self->num_matchers    = 1;
    self->num_prox        = 0;
    self->prox            = NULL;

    return self;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

