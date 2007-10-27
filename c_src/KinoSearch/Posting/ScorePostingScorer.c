#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCOREPOSTINGSCORER_VTABLE
#include "KinoSearch/Posting/ScorePostingScorer.r"

#include "KinoSearch/Posting/ScorePosting.r"
#include "KinoSearch/Index/PostingList.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/ScoreProx.r"
#include "KinoSearch/Search/Tally.r"
#include "KinoSearch/Util/Native.r"

ScorePostingScorer*
ScorePostScorer_new(Similarity *sim, PostingList *plist, void *weight,
                    float weight_value)
{
    u32_t i;
    CREATE(self, ScorePostingScorer, SCOREPOSTINGSCORER);

    /* assign */
    self->sim           = REFCOUNT_INC(sim);
    self->plist         = REFCOUNT_INC(plist);
    self->weight        = Native_new(weight);
    self->weight_value  = weight_value;

    /* init */
    self->sprox          = ScoreProx_new();
    self->tally          = Tally_new();
    Tally_Add_SProx(self->tally, self->sprox);
    self->posting        = NULL;

    /* fill score cache */
    self->score_cache = MALLOCATE(TERMSCORER_SCORE_CACHE_SIZE, float);
    for (i = 0; i < TERMSCORER_SCORE_CACHE_SIZE; i++) {
        self->score_cache[i] = Sim_TF(sim, i) * self->weight_value;
    }

    return self;
}   

Tally*
ScorePostScorer_tally(ScorePostingScorer* self) 
{
    ScoreProx *const sprox      = self->sprox;
    Tally *const tally          = self->tally;
    ScorePosting *const posting = (ScorePosting*)self->posting;
    const u32_t  freq           = posting->freq;
    
    /* calculate initial score based on frequency of term */
    tally->score = (freq < TERMSCORER_SCORE_CACHE_SIZE) 
        ? self->score_cache[freq] /* cache hit */
        : Sim_TF(self->sim, freq) * self->weight_value;

    /* factor in field-length normalization and doc/field/prox boost */
    tally->score *= posting->impact;

    /* set prox */
    sprox->num_prox = freq;
    sprox->prox     = posting->prox;

    return tally;
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

