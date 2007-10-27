#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TALLY_VTABLE
#include "KinoSearch/Search/Tally.r"

#include "KinoSearch/Search/ScoreProx.r"

/* Compare two ScoreProx objects by field number.
 */
static int
compare_sproxen(const void *va, const void *vb);

Tally*
Tally_new()
{
    CREATE(self, Tally, TALLY);

    self->score           = 0.0f;
    self->num_matchers    = 1;
    self->num_sproxen     = 0;
    self->sprox_cap       = 0;
    self->sproxen         = NULL;

    return self;
}

void
Tally_destroy(Tally *self)
{
    free(self->sproxen);
    free(self);
}

void
Tally_add_sprox(Tally *self, ScoreProx *sprox)
{
    if (self->num_sproxen >= self->sprox_cap) {
        self->sprox_cap += 1;
        self->sproxen = REALLOCATE(self->sproxen, self->sprox_cap, 
            ScoreProx*);
    }

    /* add and sort by field num */
    self->sproxen[ self->num_sproxen++ ] = sprox;
    qsort(self->sproxen, self->num_sproxen, sizeof(ScoreProx*),
        compare_sproxen);
}

void
Tally_zap_sproxen(Tally *self)
{
    self->num_sproxen = 0;
}

static int
compare_sproxen(const void *va, const void *vb) 
{
    ScoreProx *const sprox_a = (ScoreProx*)va;
    ScoreProx *const sprox_b = (ScoreProx*)vb;
    
    return sprox_a->field_num - sprox_b->field_num;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

