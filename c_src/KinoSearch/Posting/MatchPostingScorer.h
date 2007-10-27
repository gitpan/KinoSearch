#ifndef H_KINO_MATCHPOSTINGSCORER
#define H_KINO_MATCHPOSTINGSCORER 1

#include "KinoSearch/Search/TermScorer.r"

typedef struct kino_MatchPostingScorer kino_MatchPostingScorer;
typedef struct KINO_MATCHPOSTINGSCORER_VTABLE KINO_MATCHPOSTINGSCORER_VTABLE;

struct kino_Tally;
struct kino_Posting;
struct kino_PostingList;

KINO_CLASS("KinoSearch::Posting::MatchPostingScorer", "MatchPostScorer", 
    "KinoSearch::Search::TermScorer");

struct kino_MatchPostingScorer {
    KINO_MATCHPOSTINGSCORER_VTABLE *_;
    KINO_TERMSCORER_MEMBER_VARS;
};

/* Constructor. 
 */
kino_MatchPostingScorer*
kino_MatchPostScorer_new(struct kino_Similarity *sim, 
                         struct kino_PostingList *plist, 
                         void *weight, float weight_value);

KINO_END_CLASS

#endif /* H_KINO_MATCHPOSTINGSCORER */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

