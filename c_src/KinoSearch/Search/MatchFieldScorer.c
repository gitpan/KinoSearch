#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_MATCHFIELDSCORER_VTABLE
#include "KinoSearch/Search/MatchFieldScorer.r"

#include "KinoSearch/Search/HitCollector.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/Tally.r"
#include "KinoSearch/Util/Native.r"
#include "KinoSearch/Util/IntMap.r"

MatchFieldScorer*
MatchFieldScorer_new(Similarity *sim, IntMap *sort_cache, void *weight)
{
    CREATE(self, MatchFieldScorer, MATCHFIELDSCORER);

    /* assign */
    self->sim           = REFCOUNT_INC(sim);
    self->sort_cache    = REFCOUNT_INC(sort_cache);
    self->weight        = Native_new(weight);

    /* init */
    self->tally         = Tally_new();
    self->doc_num       = -1;

    return self;
}   

void
MatchFieldScorer_destroy(MatchFieldScorer *self) 
{
    REFCOUNT_DEC(self->sim);
    REFCOUNT_DEC(self->tally);
    REFCOUNT_DEC(self->sort_cache);
    REFCOUNT_DEC(self->weight);
    free(self);
}

bool_t
MatchFieldScorer_next(MatchFieldScorer* self) 
{
    while (1) {
        if (++self->doc_num >= self->sort_cache->size) {
            self->doc_num--;
            return false;
        }
        if (IntMap_Get(self->sort_cache, self->doc_num) >= 0) {
            return true;
        }
    }
}

Tally*
MatchFieldScorer_tally(MatchFieldScorer* self) 
{
    return self->tally;
}

u32_t 
MatchFieldScorer_doc(MatchFieldScorer* self) 
{
    return self->doc_num;
}


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

