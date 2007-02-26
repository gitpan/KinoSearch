#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SORTCOLLECTOR_VTABLE
#include "KinoSearch/Search/SortCollector.r"

#include "KinoSearch/Search/FieldDoc.r"
#include "KinoSearch/Search/FieldDocCollator.r"
#include "KinoSearch/Search/HitQueue.r"
#include "KinoSearch/Search/SortedHitQueue.r"

static void
SortColl_collect(SortCollector *self, u32_t doc_num, float score);

SortCollector*
SortColl_new(FieldDocCollator *collator, u32_t num_hits) 
{
    CREATE(self, SortCollector, SORTCOLLECTOR);

    /* init */
    self->collect     = (HC_collect_t)SortColl_collect;
    self->release     = NULL; /* not needed, destroy overridden */
    self->data        = NULL; /* not needed */
    self->min_doc     = -1;
    self->min_score   = 0.0f;
    self->total_hits  = 0;
    self->num_hits    = 0;

    /* assign */
    self->num_hits = num_hits;
    REFCOUNT_INC(collator);
    self->collator = collator;

    /* derive */
    self->hit_q       = (HitQueue*)SortedHitQ_new(num_hits);

    return self;
}

void
SortColl_destroy(SortCollector *self) 
{
    REFCOUNT_DEC(self->collator);
    REFCOUNT_DEC(self->hit_q);
    free(self);
}


static void
SortColl_collect(SortCollector *self, u32_t doc_num, float score) 
{
    /* add to the total number of hits */
    self->total_hits++;

    /* bail if the doc doesn't sort higher than the current bubble */
    if (   self->total_hits > self->num_hits 
        && ( !FDocCollator_Compare(self->collator, doc_num, score,
              self->min_doc, self->min_score) )
    ) {
        return;
    }
    else {
        FieldDoc *const field_doc 
            = FieldDoc_new(doc_num, score, self->collator);
        SortedHitQueue *const hit_q = (SortedHitQueue*)self->hit_q;

        SortedHitQ_Insert(hit_q, field_doc);

        /* store the bubble score in a more accessible spot */
        if (hit_q->size == hit_q->max_size) {
            FieldDoc *const least = (FieldDoc*)SortedHitQ_Peek(hit_q);
            self->min_doc   = least->id;
            self->min_score = least->score;
        }
    }
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

