#ifndef H_KINO_RICHPOSTINGSCORER
#define H_KINO_RICHPOSTINGSCORER 1

#include "KinoSearch/Posting/ScorePostingScorer.r"

typedef struct kino_RichPostingScorer kino_RichPostingScorer;
typedef struct KINO_RICHPOSTINGSCORER_VTABLE KINO_RICHPOSTINGSCORER_VTABLE;

KINO_CLASS("KinoSearch::Posting::RichPostingScorer", "RichPostScorer", 
    "KinoSearch::Posting::ScorePostingScorer");

struct kino_RichPostingScorer {
    KINO_RICHPOSTINGSCORER_VTABLE *_;
    KINO_TERMSCORER_MEMBER_VARS;
};

/* Constructor. 
 */
kino_RichPostingScorer*
kino_RichPostScorer_new(struct kino_Similarity *sim, 
                        struct kino_PostingList *plist, 
                        void *weight_ref, float weight_value);

KINO_END_CLASS

#endif /* H_KINO_RICHPOSTINGSCORER */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

