#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/RangeScorer.h"
#include "KinoSearch/Index/SortCache.h"

RangeScorer*
RangeScorer_new(i32_t lower_bound, i32_t upper_bound, SortCache *sort_cache,
                i32_t doc_max)
{
    RangeScorer *self = (RangeScorer*)VTable_Make_Obj(&RANGESCORER);
    return RangeScorer_init(self, lower_bound, upper_bound, sort_cache,
        doc_max);
}

RangeScorer*
RangeScorer_init(RangeScorer *self, i32_t lower_bound, i32_t upper_bound,
                 SortCache *sort_cache, i32_t doc_max)
{
    Matcher_init((Matcher*)self);

    /* Init. */
    self->doc_id       = 0;

    /* Assign. */
    self->lower_bound  = lower_bound;
    self->upper_bound  = upper_bound;
    self->sort_cache   = (SortCache*)INCREF(sort_cache);
    self->doc_max      = doc_max;

    /* Derive. */

    return self;
}   

void
RangeScorer_destroy(RangeScorer *self)
{
    DECREF(self->sort_cache);
    SUPER_DESTROY(self, RANGESCORER);
}

i32_t
RangeScorer_next(RangeScorer* self) 
{
    while(1) {
        if (++self->doc_id > self->doc_max) {
            self->doc_id--;
            return 0;
        }
        else {
            /* Check if ord for this document is within the specied range. */
            /* TODO: Unroll? i.e. use SortCache_Get_Ords at constructor time
             * and save ourselves some method call overhead. */
            const i32_t ord = SortCache_Ordinal(self->sort_cache, self->doc_id);
            if (ord >= self->lower_bound && ord <= self->upper_bound) {
                break;
            }
        }
    }
    return self->doc_id;
}

i32_t
RangeScorer_advance(RangeScorer* self, i32_t target) 
{
    self->doc_id = target - 1;
    return RangeScorer_next(self);
}

float
RangeScorer_score(RangeScorer* self) 
{
    UNUSED_VAR(self);
    return 0.0f;
}

i32_t 
RangeScorer_get_doc_id(RangeScorer* self) 
{
    return self->doc_id;
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

