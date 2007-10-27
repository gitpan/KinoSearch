#ifndef H_KINO_ANDORSCORER
#define H_KINO_ANDORSCORER 1

#include "KinoSearch/Search/Scorer.r"

struct kino_Similarity;
struct kino_Tally;
struct kino_VArray;

typedef struct kino_ANDORScorer kino_ANDORScorer;
typedef struct KINO_ANDORSCORER_VTABLE KINO_ANDORSCORER_VTABLE;

KINO_CLASS("KinoSearch::Search::ANDORScorer", "ANDORScorer",
    "KinoSearch::Search::Scorer");

struct kino_ANDORScorer {
    KINO_ANDORSCORER_VTABLE *_;
    KINO_SCORER_MEMBER_VARS;
    struct kino_Tally   *tally;
    kino_Scorer         *and_scorer;   /**< required scorer */
    kino_Scorer         *or_scorer;    /**< optional scorer */
    chy_bool_t           or_scorer_first_time;
};

/* Constructor.
 */
kino_ANDORScorer* 
kino_ANDORScorer_new(struct kino_Similarity *sim, 
                     struct kino_Scorer *and_scorer, 
                     struct kino_Scorer *or_scorer);

void
kino_ANDORScorer_destroy(kino_ANDORScorer *self);
KINO_METHOD("Kino_ANDORScorer_Destroy");

chy_bool_t
kino_ANDORScorer_next(kino_ANDORScorer *self);
KINO_METHOD("Kino_ANDORScorer_Next");

chy_bool_t
kino_ANDORScorer_skip_to(kino_ANDORScorer *self, chy_u32_t target);
KINO_METHOD("Kino_ANDORScorer_Skip_To");

struct kino_Tally*
kino_ANDORScorer_tally(kino_ANDORScorer *self);
KINO_METHOD("Kino_ANDORScorer_Tally");

chy_u32_t 
kino_ANDORScorer_doc(kino_ANDORScorer *self);
KINO_METHOD("Kino_ANDORScorer_Doc");

chy_u32_t
kino_ANDORScorer_max_matchers(kino_ANDORScorer *self);
KINO_METHOD("Kino_ANDORScorer_Max_Matchers");

KINO_END_CLASS

#endif /* H_KINO_ANDORSCORER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

