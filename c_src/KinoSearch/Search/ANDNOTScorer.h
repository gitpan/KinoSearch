#ifndef H_KINO_ANDNOTSCORER
#define H_KINO_ANDNOTSCORER 1

#include "KinoSearch/Search/Scorer.r"

struct kino_Similarity;
struct kino_Tally;
struct kino_VArray;

typedef struct kino_ANDNOTScorer kino_ANDNOTScorer;
typedef struct KINO_ANDNOTSCORER_VTABLE KINO_ANDNOTSCORER_VTABLE;

KINO_CLASS("KinoSearch::Search::ANDNOTScorer", "ANDNOTScorer",
    "KinoSearch::Search::Scorer");

struct kino_ANDNOTScorer {
    KINO_ANDNOTSCORER_VTABLE *_;
    KINO_SCORER_MEMBER_VARS;
    kino_Scorer         *and_scorer; /**< required scorer */
    kino_Scorer         *not_scorer; /**< negated (prohibited) scorer */
    chy_bool_t           first_time;
};

/* Constructor.
 */
kino_ANDNOTScorer* 
kino_ANDNOTScorer_new(struct kino_Similarity *sim, 
                      struct kino_Scorer *and_scorer, 
                      struct kino_Scorer *not_scorer);

void
kino_ANDNOTScorer_destroy(kino_ANDNOTScorer *self);
KINO_METHOD("Kino_ANDNOTScorer_Destroy");

chy_bool_t
kino_ANDNOTScorer_next(kino_ANDNOTScorer *self);
KINO_METHOD("Kino_ANDNOTScorer_Next");

chy_bool_t
kino_ANDNOTScorer_skip_to(kino_ANDNOTScorer *self, chy_u32_t target);
KINO_METHOD("Kino_ANDNOTScorer_Skip_To");

struct kino_Tally*
kino_ANDNOTScorer_tally(kino_ANDNOTScorer *self);
KINO_METHOD("Kino_ANDNOTScorer_Tally");

chy_u32_t 
kino_ANDNOTScorer_doc(kino_ANDNOTScorer *self);
KINO_METHOD("Kino_ANDNOTScorer_Doc");

KINO_END_CLASS

#endif /* H_KINO_ANDNOTSCORER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

