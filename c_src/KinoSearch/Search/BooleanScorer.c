#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_BOOLEANSCORER_VTABLE
#include "KinoSearch/Search/BooleanScorer.r"

#include "KinoSearch/Search/Similarity.r"

#define MATCH_BATCH_SIZE (1 << 11)
#define MATCH_BATCH_DOC_MASK (MATCH_BATCH_SIZE - 1)

struct MatchBatch {
    u32_t     count;
    float    *scores;
    u32_t    *matcher_counts;
    u32_t    *bool_masks;
    u32_t    *recent_docs;
};

struct BoolSubScorer {
    Scorer        *scorer;
    u32_t          bool_mask;
    bool_t         done;
    BoolSubScorer *next_subscorer;
};

/* Constructor for a MatchBatch.
 */
static MatchBatch* 
new_mbatch(void);

/* Return a MatchBatch to a "zeroed" state.  Only the matcher_counts and the
 * count are actually cleared; the rest get initialized the next time a doc
 * gets captured. */
static void 
clear_mbatch(MatchBatch *match_batch);

/* BooleanScorers award bonus points to documents which match multiple
 * subqueries.  This routine calculates the size of the bonuses. 
 */
static void
compute_coord_factors(BooleanScorer *scorer);

/* Build up the array of positions which match this query within the current
 * doc.
 */
static void
build_prox(BooleanScorer *self);

/* Comparison op for qsorting an array of u32_t.
 */
static int
compare_u32(const void *va, const void *vb);

BooleanScorer*
BoolScorer_new(Similarity *sim) 
{
    CREATE(self, BooleanScorer, BOOLEANSCORER);

    /* assign */
    self->sim = sim;
    REFCOUNT_INC(sim);

    /* init */
    self->doc_num          = 0;
    self->end              = 0;
    self->max_coord        = 1;
    self->coord_factors    = NULL;
    self->required_mask    = 0;
    self->prohibited_mask  = 0;
    self->next_mask        = 1;
    self->mbatch           = new_mbatch();
    self->subscorers       = NULL;
    self->raw_prox_bb      = BB_new(0);
    self->num_prox         = 0;

    return self;
}

void
BoolScorer_destroy(BooleanScorer *self) 
{
    BoolSubScorer   *sub;

    if (self->mbatch != NULL) {
        free(self->mbatch->scores);
        free(self->mbatch->matcher_counts);
        free(self->mbatch->bool_masks);
        free(self->mbatch->recent_docs);
        free(self->mbatch);
    }

    /* individual scorers will be GC'd on their own */
    sub = self->subscorers;
    while (sub != NULL) {
        BoolSubScorer *const next_sub = sub->next_subscorer;
        REFCOUNT_DEC(sub->scorer);
        free(sub);
        sub = next_sub;
    }

    REFCOUNT_DEC(self->raw_prox_bb);
    REFCOUNT_DEC(self->sim);
    free(self->coord_factors);

    free(self);
}

static MatchBatch*
new_mbatch() 
{
    MatchBatch* mbatch = MALLOCATE(1, MatchBatch);

    /* allocate and init */
    mbatch->scores            = MALLOCATE(MATCH_BATCH_SIZE, float);
    mbatch->matcher_counts    = MALLOCATE(MATCH_BATCH_SIZE, u32_t);
    mbatch->bool_masks        = MALLOCATE(MATCH_BATCH_SIZE, u32_t);
    mbatch->recent_docs       = MALLOCATE(MATCH_BATCH_SIZE, u32_t);
    mbatch->count             = 0;

    return mbatch;
}

static void
clear_mbatch(MatchBatch *mbatch) 
{
    memset(mbatch->matcher_counts, 0, MATCH_BATCH_SIZE * sizeof(u32_t));
    mbatch->count = 0;
}

static void
compute_coord_factors(BooleanScorer *self) 
{
    float *coord_factors;
    u32_t  i;
    Similarity *const sim = self->sim;
    const u32_t max_coord = self->max_coord;

    self->coord_factors = MALLOCATE((max_coord + 1), float);
    coord_factors = self->coord_factors;

    for (i = 0; i <= self->max_coord; i++) {
        *coord_factors++ = Sim_Coord(sim, i, max_coord);
    }
}

void
BoolScorer_add_subscorer(BooleanScorer* self, Scorer* subscorer,
                              char *occur) 
{
    BoolSubScorer *bool_subscorer = MALLOCATE(1, BoolSubScorer);

    REFCOUNT_INC(subscorer);

    bool_subscorer->scorer = subscorer;

    /* if this scorer is required or negated, assign it a unique mask bit. */
    if (strcmp(occur, "SHOULD") == 0) {
        bool_subscorer->bool_mask = 0;
        self->max_coord++;
    }
    else {
        if (self->next_mask == 0) {
            CONFESS("more than 32 required or prohibited clauses");
        }
        bool_subscorer->bool_mask = self->next_mask;
        self->next_mask <<= 1;

        if (strcmp(occur, "MUST_NOT") == 0) {
            self->prohibited_mask |= bool_subscorer->bool_mask;
        }
        else { /* "MUST" occur */
            self->max_coord++;
            self->required_mask |= bool_subscorer->bool_mask;
        }
    }

    /* prime the pump */
    bool_subscorer->done = !Scorer_Next(subscorer);

    /* link up the linked list of subscorers */
    bool_subscorer->next_subscorer = self->subscorers;
    self->subscorers = bool_subscorer;
}

bool_t
BoolScorer_next(BooleanScorer* self) 
{
    MatchBatch *const mbatch = self->mbatch;
    bool_t more;
    BoolSubScorer *sub;

    do {
        while (mbatch->count-- > 0) { 

            /* check to see if the doc is prohibited */
            const u32_t doc        = mbatch->recent_docs[ mbatch->count ];
            const u32_t masked_doc = doc & MATCH_BATCH_DOC_MASK;
            const u32_t bool_mask  = mbatch->bool_masks[masked_doc];
            if (   (bool_mask & self->prohibited_mask) == 0
                && (bool_mask & self->required_mask) 
                        == self->required_mask
            ) {
                /* it's not prohibited, so next() was successful */
                self->doc_num = doc;
                build_prox(self);
                return true;
            }
        }

        /* refill the queue, processing all docs within the next range */
        clear_mbatch(mbatch);
        more = 0;
        self->end += MATCH_BATCH_SIZE;
        
        /* iterate through subscorers, caching results to the MatchBatch */
        for (sub = self->subscorers; 
             sub != NULL; 
             sub = sub->next_subscorer
        ) {
            Scorer *const subscorer = sub->scorer;
            while (!sub->done 
                   && Scorer_Doc(subscorer) < self->end
            ) {
                const u32_t doc        = Scorer_Doc(subscorer);
                const u32_t masked_doc = doc & MATCH_BATCH_DOC_MASK;
                if (mbatch->matcher_counts[masked_doc] == 0) {
                    /* first subscorer to hit this doc */
                    mbatch->recent_docs[mbatch->count] = doc;
                    mbatch->count++;
                    mbatch->matcher_counts[masked_doc] = 1;
                    mbatch->scores[masked_doc] = Scorer_Score(subscorer);
                    mbatch->bool_masks[masked_doc] = sub->bool_mask;
                }
                else {
                    mbatch->matcher_counts[masked_doc]++;
                    mbatch->scores[masked_doc] += Scorer_Score(subscorer);
                    mbatch->bool_masks[masked_doc] |= sub->bool_mask;
                }

                /* check whether this subscorer is exhausted */
                sub->done = !Scorer_Next(subscorer);
            }
            /* if at least one subscorer succeeded, loop back */
            if (!sub->done) {
                more = 1;
            }
        } 
    } while (mbatch->count > 0 || more);

    /* out of docs!  we're done. */
    return false;
}

float
BoolScorer_score(BooleanScorer* self) 
{
    MatchBatch *const mbatch = self->mbatch;
    u32_t             masked_doc;
    float             score;

    if (self->coord_factors == NULL) {
        compute_coord_factors(self);
    }

    /* retrieve the docs accumulated score from the MatchBatch */
    masked_doc = self->doc_num & MATCH_BATCH_DOC_MASK;
    score = mbatch->scores[masked_doc];

    /* add coordination bonus based on position hits -- disbled for now */
    /* score *= Sim_Prox_Coord(self->sim, self->prox, self->num_prox); */

    /* assign bonus for multi-subscorer matches */
    score *= self->coord_factors[ mbatch->matcher_counts[masked_doc] ];
    return score;
}

static void
build_prox(BooleanScorer *self)
{
    BoolSubScorer *sub = self->subscorers;
    u32_t *source, *dest, *limit;
    u32_t  num_prox = 0;
    u32_t  last_pos = U32_MAX;

    /* calculate and allocate required space */
    for ( ; sub != NULL; sub = sub->next_subscorer) {
        num_prox += sub->scorer->num_prox;
    }
    BB_Grow(self->raw_prox_bb, num_prox * sizeof(u32_t));
    self->raw_prox_bb->len = num_prox * sizeof(u32_t);

    /* copy positions from subscorers */
    dest = (u32_t*)self->raw_prox_bb->ptr;
    for (sub = self->subscorers; sub != NULL; sub = sub->next_subscorer) {
        Scorer *const subscorer = sub->scorer;
        memcpy(dest, subscorer->prox, subscorer->num_prox * sizeof(u32_t));
        dest += subscorer->num_prox;
    }

    /* sort positions, then filter dupes */
    if (num_prox) {
        qsort(self->raw_prox_bb->ptr, num_prox, sizeof(u32_t), compare_u32);
        source = (u32_t*)self->raw_prox_bb->ptr;
        limit  = (u32_t*)BBEND(self->raw_prox_bb);
        dest   = source;
        for ( ; source < limit; source++) {
            if (last_pos != *source) {
                *dest++ = *source;
                last_pos = *source;
            }
        }
    }
    self->prox = (u32_t*)self->raw_prox_bb->ptr;
    self->num_prox = dest - self->prox;
    self->raw_prox_bb->len = self->num_prox * sizeof(u32_t);
}

static int
compare_u32(const void *va, const void *vb)
{
    const u32_t *a = (u32_t*)va;
    const u32_t *b = (u32_t*)vb;
    if (*a < *b) 
        return -1;
    else if (*a == *b)
        return 0;
    else
        return 1;
}

u32_t
BoolScorer_doc(BooleanScorer* self) 
{
    return self->doc_num;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

