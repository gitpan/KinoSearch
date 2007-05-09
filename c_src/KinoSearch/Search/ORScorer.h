/**
 * @class KinoSearch::Search::ORScorer OrScorer.r
 * @brief Union results of multiple Scorers.
 * 
 * ORScorer collates the output of multiple subscorers, summing their scores
 * whenever they match the same document.
 */

#ifndef H_KINO_ORSCORER
#define H_KINO_ORSCORER 1

#include "KinoSearch/Search/Scorer.r"

struct kino_Similarity;
struct kino_Tally;
struct kino_VArray;

typedef struct kino_ORScorer kino_ORScorer;
typedef struct KINO_ORSCORER_VTABLE KINO_ORSCORER_VTABLE;

KINO_CLASS("KinoSearch::Search::ORScorer", "ORScorer",
    "KinoSearch::Search::Scorer");

struct kino_ORScorer {
    KINO_ORSCORER_VTABLE *_;
    KINO_SCORER_MEMBER_VARS;
    struct kino_Tally           *tally;
    struct kino_VArray          *subscorers;
    struct kino_ScorerDocQueue  *q;
    chy_u32_t                    num_subs;
    float                       *scores;
    chy_u32_t                    doc_num;
};

/* Constructor.
 */
kino_ORScorer* 
kino_ORScorer_new(struct kino_Similarity *sim, 
                  struct kino_VArray* sub_scorers);

void
kino_ORScorer_destroy(kino_ORScorer *self);
KINO_METHOD("Kino_ORScorer_Destroy");

chy_bool_t
kino_ORScorer_next(kino_ORScorer *self);
KINO_METHOD("Kino_ORScorer_Next");

chy_bool_t
kino_ORScorer_skip_to(kino_ORScorer *self, chy_u32_t target);
KINO_METHOD("Kino_ORScorer_Skip_To");

struct kino_Tally*
kino_ORScorer_tally(kino_ORScorer *self);
KINO_METHOD("Kino_ORScorer_Tally");

chy_u32_t 
kino_ORScorer_doc(kino_ORScorer *self);
KINO_METHOD("Kino_ORScorer_Doc");

KINO_END_CLASS

#endif /* H_KINO_ORSCORER */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

