#ifndef H_KINO_SCOREPOSTINGSCORER
#define H_KINO_SCOREPOSTINGSCORER 1

#include "KinoSearch/Search/TermScorer.r"

typedef struct kino_ScorePostingScorer kino_ScorePostingScorer;
typedef struct KINO_SCOREPOSTINGSCORER_VTABLE KINO_SCOREPOSTINGSCORER_VTABLE;

KINO_CLASS("KinoSearch::Posting::ScorePostingScorer", "ScorePostScorer", 
    "KinoSearch::Search::TermScorer");

struct kino_ScorePostingScorer {
    KINO_SCOREPOSTINGSCORER_VTABLE *_;
    KINO_TERMSCORER_MEMBER_VARS;
};

/* Constructor. 
 */
kino_ScorePostingScorer*
kino_ScorePostScorer_new(struct kino_Similarity *sim, 
                         struct kino_PostingList *plist, 
                         void *weight, float weight_value);

struct kino_Tally*
kino_ScorePostScorer_tally(kino_ScorePostingScorer* self);
KINO_METHOD("Kino_ScorePostScorer_Tally");

KINO_END_CLASS

#endif /* H_KINO_SCOREPOSTINGSCORER */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

