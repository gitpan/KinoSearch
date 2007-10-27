/**
 * @class KinoSearch::Posting::MatchPosting  MatchPosting.r
 */
#ifndef H_KINO_MATCHPOSTING
#define H_KINO_MATCHPOSTING 1

#include "KinoSearch/Posting.r"

struct kino_MatchPostingScorer;

typedef struct kino_MatchPosting kino_MatchPosting;
typedef struct KINO_MATCHPOSTING_VTABLE KINO_MATCHPOSTING_VTABLE;

KINO_CLASS("KinoSearch::Posting::MatchPosting", "MatchPost", 
    "KinoSearch::Posting");

struct kino_MatchPosting {
    KINO_MATCHPOSTING_VTABLE *_;
    KINO_POSTING_MEMBER_VARS;
};

/* Constructor.
 */
kino_MatchPosting*
kino_MatchPost_new(struct kino_Similarity *sim);

kino_MatchPosting*
kino_MatchPost_dupe(kino_MatchPosting *self, struct kino_Similarity *sim);
KINO_METHOD("Kino_MatchPost_Dupe");

void
kino_MatchPost_reset(kino_MatchPosting *self, chy_u32_t doc_num);
KINO_METHOD("Kino_MatchPost_Reset");

struct kino_MatchPostingScorer*
kino_MatchPost_make_scorer(kino_MatchPosting *self, 
                           struct kino_Similarity *sim,
                           struct kino_PostingList *plist, 
                           void *weight, float weight_val);
KINO_METHOD("Kino_MatchPost_Make_Scorer");

KINO_END_CLASS

#endif /* H_KINO_MATCHPOSTING */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

