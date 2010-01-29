#define C_KINO_FILTERSCORER
#include "KinoSearch/Util/ToolSet.h"

#include "KSx/Search/FilterScorer.h"

FilterScorer*
FilterScorer_new(BitVector *bits, i32_t doc_max)
{
    FilterScorer *self = (FilterScorer*)VTable_Make_Obj(FILTERSCORER);
    return FilterScorer_init(self, bits, doc_max);
}

FilterScorer*
FilterScorer_init(FilterScorer *self, BitVector *bits, i32_t doc_max)
{
    Matcher_init((Matcher*)self);

    /* Init. */
    self->doc_id       = 0;

    /* Assign. */
    self->bits         = (BitVector*)INCREF(bits);
    self->doc_max      = doc_max;

    return self;
}   

void
FilterScorer_destroy(FilterScorer *self) 
{
    DECREF(self->bits);
    SUPER_DESTROY(self, FILTERSCORER);
}

i32_t
FilterScorer_next(FilterScorer* self) 
{
    do {
        if (++self->doc_id > self->doc_max) {
            self->doc_id--;
            return 0;
        }
    } while ( !BitVec_Get(self->bits, self->doc_id) );
    return self->doc_id;
}

i32_t
FilterScorer_skip_to(FilterScorer* self, i32_t target) 
{
    self->doc_id = target - 1;
    return FilterScorer_next(self);
}

float
FilterScorer_score(FilterScorer* self) 
{
    UNUSED_VAR(self);
    return 0.0f;
}

i32_t 
FilterScorer_get_doc_id(FilterScorer* self) 
{
    return self->doc_id;
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

