#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_MATCHPOSTINGSCORER_VTABLE
#include "KinoSearch/Posting/MatchPostingScorer.r"

#include "KinoSearch/Posting/MatchPosting.r"
#include "KinoSearch/Index/PostingList.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/Tally.r"
#include "KinoSearch/Util/Native.r"

MatchPostingScorer*
MatchPostScorer_new(Similarity *sim, PostingList *plist, void *weight,
                    float weight_value)
{
    CREATE(self, MatchPostingScorer, MATCHPOSTINGSCORER);

    /* assign */
    REFCOUNT_INC(sim);
    REFCOUNT_INC(plist);
    self->sim           = sim;
    self->plist         = plist;
    self->weight        = Native_new(weight);
    self->weight_value  = weight_value;

    /* init */
    self->tally          = Tally_new();
    self->sprox          = NULL;
    self->score_cache    = NULL;

    /* start off postings blob with dummy posting */
    self->postings       = BB_new_str((char*)&POST_DUMMY, sizeof(Posting));
    self->posting        = (Posting*)self->postings->ptr;

    return self;
}   


MatchPostingScorer*
MatchPost_make_scorer(MatchPosting *self, Similarity *sim, 
                      struct kino_PostingList *plist, 
                      void *weight, float weight_val)
{
    return MatchPostScorer_new(sim, plist, weight, weight_val);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

