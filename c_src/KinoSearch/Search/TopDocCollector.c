#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TOPDOCCOLLECTOR_VTABLE
#include "KinoSearch/Search/TopDocCollector.r"

#include "KinoSearch/Search/HitQueue.r"
#include "KinoSearch/Search/ScoreDoc.r"

/* Keep highest scoring docs.
 */
static void 
TDColl_collect(TopDocCollector *self, u32_t doc_num, float score);

TopDocCollector*
TDColl_new(u32_t num_hits) 
{
    CREATE(self, TopDocCollector, TOPDOCCOLLECTOR);

    /* init */
    self->collect       = (HC_collect_t)TDColl_collect;
    self->release       = NULL;
    self->min_score     = 0.0;
    self->total_hits    = 0;

    /* assign */
    self->num_hits      = num_hits;

    /* derive */
    self->hit_q         = kino_HitQ_new(num_hits);

    return self;
}

void
TDColl_destroy(TopDocCollector *self) 
{
    REFCOUNT_DEC(self->hit_q);
    free(self);
}

static void
TDColl_collect(TopDocCollector *self, u32_t doc_num, float score) 
{
    /* add to the total number of hits */
    self->total_hits++;
    
    /* bail if the score doesn't exceed the minimum */
    if (   self->total_hits > self->num_hits 
        && score < self->min_score
    ) {
        return;
    }
    else {
        ScoreDoc *const score_doc = ScoreDoc_new(doc_num, score);
        HitQueue *const hit_q     = self->hit_q;

        HitQ_Insert(hit_q, score_doc);

        /* store the bubble score in a more accessible spot */
        if (hit_q->size == hit_q->max_size) {
            ScoreDoc *const least = (ScoreDoc*)HitQ_Peek(hit_q);
            self->min_score = least->score;
        }
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

