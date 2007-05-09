#ifndef H_KINO_ANDSCORER
#define H_KINO_ANDSCORER 1

#include "KinoSearch/Search/Scorer.r"

struct kino_Similarity;
struct kino_Tally;
struct kino_VArray;

typedef struct kino_ANDScorer kino_ANDScorer;
typedef struct KINO_ANDSCORER_VTABLE KINO_ANDSCORER_VTABLE;

KINO_CLASS("KinoSearch::Search::ANDScorer", "ANDScorer",
    "KinoSearch::Search::Scorer");

struct kino_ANDScorer {
    KINO_ANDSCORER_VTABLE *_;
    KINO_SCORER_MEMBER_VARS;
    float                coord;
    struct kino_Tally   *tally;
    kino_Scorer        **subscorers;
    size_t               cap;
    chy_u32_t            num_subs;
    chy_bool_t           more;
    chy_bool_t           first_time;
    struct kino_ByteBuf *raw_prox_bb;
};

/* Constructor.
 */
kino_ANDScorer* 
kino_ANDScorer_new(struct kino_Similarity *sim);

void
kino_ANDScorer_destroy(kino_ANDScorer *self);
KINO_METHOD("Kino_ANDScorer_Destroy");

chy_bool_t
kino_ANDScorer_next(kino_ANDScorer *self);
KINO_METHOD("Kino_ANDScorer_Next");

chy_bool_t
kino_ANDScorer_skip_to(kino_ANDScorer *self, chy_u32_t target);
KINO_METHOD("Kino_ANDScorer_Skip_To");

struct kino_Tally*
kino_ANDScorer_tally(kino_ANDScorer *self);
KINO_METHOD("Kino_ANDScorer_Tally");

chy_u32_t 
kino_ANDScorer_doc(kino_ANDScorer *self);
KINO_METHOD("Kino_ANDScorer_Doc");

/* Add a scorer for a sub-query.
 */
void
kino_ANDScorer_add_subscorer(kino_ANDScorer* self, 
                              kino_Scorer* subscorer);
KINO_METHOD("Kino_ANDScorer_Add_Subscorer");

KINO_END_CLASS

#endif /* H_KINO_ANDSCORER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

