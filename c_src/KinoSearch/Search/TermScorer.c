#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TERMSCORER_VTABLE
#include "KinoSearch/Search/TermScorer.r"

#include "KinoSearch/Index/TermDocs.r"
#include "KinoSearch/Search/HitCollector.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Util/CClass.r"

/* Derive float boosts by averaging all decodeed boost_bytes for each TermDoc. 
 */
static void
calc_boosts(TermScorer *self);

TermScorer*
TermScorer_new(Similarity *sim)
{
    CREATE(self, TermScorer, TERMSCORER);

    /* assign */
    self->sim = sim;
    REFCOUNT_INC(sim);

    /* init */
    self->doc_num       = 0;
    self->term_docs     = NULL;
    self->pointer       = 0;
    self->pointer_max   = 0;
    self->weight_value  = 0.0;
    self->score_cache   = NULL;
    self->doc_nums      = NULL;
    self->freqs         = NULL;
    self->boosts        = NULL;
    self->prox          = NULL;
    self->num_prox      = 0;
    self->weight_ref    = NULL;

    /* allocate 1 each */
    self->field_boosts_bb = BB_new(sizeof(char));
    self->doc_nums_bb   = BB_new(sizeof(u32_t));
    self->freqs_bb      = BB_new(sizeof(float));
    self->boosts_bb     = BB_new(sizeof(float));
    self->pos_boosts_bb = BB_new(0);
    self->raw_prox_bb   = BB_new(sizeof(u32_t));

    return self;
}   

void
TermScorer_destroy(TermScorer *self) 
{
    free(self->score_cache);

    REFCOUNT_DEC(self->sim);
    REFCOUNT_DEC(self->term_docs);
    if (self->weight_ref != NULL)
        CClass_svrefcount_dec(self->weight_ref);

    REFCOUNT_DEC(self->doc_nums_bb);
    REFCOUNT_DEC(self->field_boosts_bb);
    REFCOUNT_DEC(self->freqs_bb);
    REFCOUNT_DEC(self->boosts_bb);
    REFCOUNT_DEC(self->pos_boosts_bb);
    REFCOUNT_DEC(self->raw_prox_bb);

    free(self);
}

void
TermScorer_fill_score_cache(TermScorer *self) 
{
    float *cache_ptr;
    Similarity *const sim = self->sim;
    u32_t i;

    free(self->score_cache);
    self->score_cache = MALLOCATE(KINO_SCORE_CACHE_SIZE, float);

    cache_ptr = self->score_cache;
    for (i = 0; i < KINO_SCORE_CACHE_SIZE; i++) {
        *cache_ptr++ = Sim_TF(sim, i) * self->weight_value;
    }
}

bool_t
TermScorer_next(TermScorer* self) 
{
    /* refill the queue if needed */
    if (++self->pointer >= self->pointer_max) {
        self->pointer_max = TermDocs_Bulk_Read(self->term_docs, 
            self->doc_nums_bb, self->field_boosts_bb,  self->freqs_bb, 
            self->raw_prox_bb, self->pos_boosts_bb, 1024);
        self->doc_nums      = (u32_t*)self->doc_nums_bb->ptr;
        self->freqs         = (u32_t*)self->freqs_bb->ptr;
        self->prox          = (u32_t*)self->raw_prox_bb->ptr;
        self->num_prox      = self->freqs[0];
        calc_boosts(self);
        if (self->pointer_max != 0) {
            self->pointer = 0;
        }
        else {
            self->doc_num = KINO_TERM_SCORER_SENTINEL;

            /* reclaim resources a little early */
            REFCOUNT_DEC(self->term_docs);
            self->term_docs = NULL;

            return false;
        }
    }
    else {
        self->prox += self->num_prox;
        self->num_prox = self->freqs[ self->pointer ];
    }

    self->doc_num = self->doc_nums[ self->pointer ];
    return true;
}

static void
calc_boosts(TermScorer *self)
{
    float *norm_decoder  = self->sim->norm_decoder;
    const size_t space   = self->freqs_bb->len * sizeof(float) / sizeof(u32_t);

    /* allocate space if necessary and get a fresh pointer */
    BB_Grow(self->boosts_bb, space);
    self->boosts_bb->len = space;
    self->boosts = (float*)self->boosts_bb->ptr;

    /* store_field_boost */
    if (self->field_boosts_bb->len > 0) {
        u8_t        *field_boosts  = (u8_t*)self->field_boosts_bb->ptr;
        u8_t *const limit          = (u8_t*)BBEND(self->field_boosts_bb);
        float       *boosts        = self->boosts;

        for ( ; field_boosts < limit; field_boosts++, boosts++) {
            *boosts = norm_decoder[ *field_boosts ];
        }
    }
    else {
        float       *boosts  = self->boosts;
        float *const limit   = (float*)BBEND(self->boosts_bb);
        while (boosts < limit) {
            *boosts++ = 1.0;
        }
    }

    /* store_pos_boost - multiply field boost by average pos boost */
    if (self->pos_boosts_bb->len > 0) {
        float       *boosts  = self->boosts;
        float *const limit   = (float*)BBEND(self->boosts_bb);
        u32_t       *freqs   = self->freqs;
        u8_t        *pos_boosts = (u8_t*)self->pos_boosts_bb->ptr;

        for ( ; boosts < limit; freqs++, boosts++) {
            u32_t i;
            float average_boost = 0.0;
            
            /* add one boost for each posting */
            for (i = 0; i < *freqs; i++) {
                average_boost += norm_decoder[ *pos_boosts++ ];
            }

            /* average the amount and factor it in */
            average_boost /= *freqs;
            *boosts *= average_boost;
        }
    }
}

float
TermScorer_score(TermScorer* self) 
{
    const u32_t freq = self->freqs[ self->pointer ];
    float score = (freq < KINO_SCORE_CACHE_SIZE) 
        ? self->score_cache[freq] /* cache hit */
        : Sim_TF(self->sim, freq) * self->weight_value;

    /* normalize for field */
    score *= self->boosts[ self->pointer ];

    return score;
}

u32_t 
TermScorer_doc(TermScorer* self) 
{
    return self->doc_num;
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

