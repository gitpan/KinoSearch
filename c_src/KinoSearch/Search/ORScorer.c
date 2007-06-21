#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_ORSCORER_VTABLE
#include "KinoSearch/Search/ORScorer.r"

#include "KinoSearch/Search/ScorerDocQueue.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/Tally.r"

/* Move all scorers ahead so that they are at least as 
 */
static bool_t
advance_after_current(ORScorer *self);

ORScorer*
ORScorer_new(Similarity *sim, VArray *subscorers) 
{
    u32_t i;
    CREATE(self, ORScorer, ORSCORER);

    /* assign */
    REFCOUNT_INC(sim);
    REFCOUNT_INC(subscorers);
    self->sim              = sim;
    self->subscorers       = subscorers;

    /* init */
    self->doc_num          = DOC_NUM_SENTINEL;  /* really ought to be -1 */
    self->tally            = Tally_new();
    self->q                = NULL;

    /* derive */
    self->num_subs         = subscorers->size;
    self->scores           = MALLOCATE(self->num_subs, float);

    /* initialize ScorerDocQueue */
    self->q        = ScorerDocQ_new(subscorers->size);
    for (i = 0; i < subscorers->size; i++) {
        Scorer *scorer = (Scorer*)VA_Fetch(subscorers, i);
        if (Scorer_Next(scorer)) {
            ScorerDocQ_Put(self->q, scorer);
        }
    }

    return self;
}

void
ORScorer_destroy(ORScorer *self) 
{
    REFCOUNT_DEC(self->sim);
    REFCOUNT_DEC(self->tally);
    REFCOUNT_DEC(self->q);
    REFCOUNT_DEC(self->subscorers);
    free(self->scores);
    free(self);
}

bool_t
ORScorer_next(ORScorer *self)
{
    return advance_after_current(self);
}

static bool_t
advance_after_current(ORScorer *self) {
    ScorerDocQueue *const q      = self->q;
    float *const          scores = self->scores;
    Tally *const          tally  = self->tally;
    Tally *subtally;

    /* if no scorers, we're done */
    if ( SCORERDOCQ_SIZE(q) == 0)
        return false;

    /* the top scorer will already be at the correct doc, so start with it */
    self->doc_num       = SCORERDOCQ_PEEK_DOC(q);
    subtally            = SCORERDOCQ_PEEK_TALLY(q);
    scores[0]           = subtally->score;
    
    tally->num_matchers = 1;

    do {
        /* attempt to advance past current doc */
        if ( !Kino_ScorerDocQ_Top_Next(q) ) {
            if (!SCORERDOCQ_SIZE(q))
                break; /* bail, no more to advance */
        }

        if (SCORERDOCQ_PEEK_DOC(q) != self->doc_num) {
            /* bail, least doc in queue is now past the one we're scoring */
            break;
        }
        else {
            /* accumulate score */
            subtally = SCORERDOCQ_PEEK_TALLY(q); 
            scores[ tally->num_matchers ] = subtally->score;
            tally->num_matchers++; 
        }
    } while (true);

    return true;
}

bool_t
ORScorer_skip_to(ORScorer *self, u32_t target)
{
    ScorerDocQueue *const q      = self->q;

    if (SCORERDOCQ_SIZE(q) == 0)
        return false;

    /* succeed if we're already past and still on a valid doc */
    if (target <= self->doc_num) {
        if (self->doc_num == DOC_NUM_SENTINEL)
            self->doc_num = 0;
        else
            return true;
    }

    do {
        /* if all scorers are caught up, accumulate score and return */
        if (SCORERDOCQ_PEEK_DOC(q) >= target) {
            return advance_after_current(self);
        }

        /* not caught up yet, so keep skipping scorers */
        if ( !ScorerDocQ_Top_Skip_To(q, target) ) {
            if (SCORERDOCQ_SIZE(q) == 0)
                return false;
        }
    } while (true);
}

chy_u32_t
ORScorer_doc(ORScorer *self)
{
    return self->doc_num;
}

Tally*
ORScorer_tally(ORScorer *self)
{
    u32_t i;
    Tally *const tally = self->tally;
    float *const scores = self->scores;
    
    /* accumulate score */
    tally->score = 0.0;
    for (i = 0; i < tally->num_matchers; i++) {
        tally->score += scores[i];
    }

    return self->tally;
}

u32_t
ORScorer_max_matchers(ORScorer *self)
{
    return self->num_subs;
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

