#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCOREPROX_VTABLE
#include "KinoSearch/Search/ScoreProx.r"

ScoreProx*
ScoreProx_new()
{
    CREATE(self, ScoreProx, SCOREPROX);

    self->field_num       = -1;
    self->num_prox        = 0;
    self->prox            = NULL;

    return self;
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

