#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_HITQUEUE_VTABLE
#include "KinoSearch/Search/HitQueue.r"

#include "KinoSearch/Search/ScoreDoc.r"

/* Compare score first, doc id second. 
 */
static bool_t
HitQ_less_than(const void *a, const void *b);

/* Decrement the refcount of a ScoreDoc.
 */
static void
HitQ_free_elem(void *elem);

HitQueue*
HitQ_new(u32_t max_size) 
{
    CREATE(self, HitQueue, HITQUEUE);
    PriQ_init_base((PriorityQueue*)self, max_size, HitQ_less_than, 
        HitQ_free_elem);
    return self;
}

static bool_t
HitQ_less_than(const void *a, const void *b) 
{
    ScoreDoc *score_doc_a = (ScoreDoc*)a;
    ScoreDoc *score_doc_b = (ScoreDoc*)b;

    if (score_doc_a->score == score_doc_b->score) {
        /* sort by doc_num second */
        return score_doc_a->id > score_doc_b->id;
    }
    else {
        /* sort by score first */
        return score_doc_a->score < score_doc_b->score;
    }
}

static void
HitQ_free_elem(void *elem) 
{
    REFCOUNT_DEC((Obj*)elem);
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

