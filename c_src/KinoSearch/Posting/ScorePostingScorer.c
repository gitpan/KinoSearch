#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCOREPOSTINGSCORER_VTABLE
#include "KinoSearch/Posting/ScorePostingScorer.r"

#include "KinoSearch/Posting/ScorePosting.r"
#include "KinoSearch/Index/PostingList.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/Tally.r"
#include "KinoSearch/Util/CClass.r"

ScorePostingScorer*
ScorePostScorer_new(Similarity *sim, PostingList *plist, void *weight_ref,
                    float weight_value)
{
    u32_t i;
    CREATE(self, ScorePostingScorer, SCOREPOSTINGSCORER);

    /* assign */
    REFCOUNT_INC(sim);
    REFCOUNT_INC(plist);
    self->sim           = sim;
    self->plist         = plist;
    self->weight_ref    = weight_ref;
    self->weight_value  = weight_value;

    /* init */
    self->tally          = Tally_new();

    /* start off postings blob with dummy posting */
    self->postings       = BB_new_str((char*)&POST_DUMMY, sizeof(Posting));
    self->posting        = (Posting*)self->postings->ptr;

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
    tally->num_prox = freq;
    tally->prox     = posting->prox;

    return tally;
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

