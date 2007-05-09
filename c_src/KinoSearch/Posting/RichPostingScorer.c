#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_RICHPOSTINGSCORER_VTABLE
#include "KinoSearch/Posting/RichPostingScorer.r"

#include "KinoSearch/Posting/ScorePostingScorer.r"
#include "KinoSearch/Posting/RichPosting.r"
#include "KinoSearch/Index/PostingList.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/Tally.r"
#include "KinoSearch/Util/CClass.r"

RichPostingScorer*
RichPostScorer_new(Similarity *sim, PostingList *plist, void *weight_ref,
                   float weight_value)
{
    RichPostingScorer *self = (RichPostingScorer*)ScorePostScorer_new(sim, 
        plist, weight_ref, weight_value);
    self->_ = &RICHPOSTINGSCORER;  /* rebless */
    return self;
}   

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

