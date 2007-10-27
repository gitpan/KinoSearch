#ifndef H_KINO_BOOLEANSCORER
#define H_KINO_BOOLEANSCORER 1

#include "KinoSearch/Search/Scorer.r"

struct kino_Similarity;
struct kino_Tally;
struct kino_VArray;

typedef struct kino_BooleanScorer kino_BooleanScorer;
typedef struct KINO_BOOLEANSCORER_VTABLE KINO_BOOLEANSCORER_VTABLE;

KINO_CLASS("KinoSearch::Search::BooleanScorer", "BoolScorer",
    "KinoSearch::Search::Scorer");

struct kino_BooleanScorer {
    KINO_BOOLEANSCORER_VTABLE *_;
    KINO_SCORER_MEMBER_VARS;
    struct kino_Scorer         *scorer; /**< configurable internal Scorer */
    struct kino_Tally          *tally;
    struct kino_VArray         *and_scorers;
    struct kino_VArray         *or_scorers;
    struct kino_VArray         *not_scorers;
    chy_u32_t                   max_coord;
    float                      *coord_factors;
    kino_Scorer_next_t          do_next;
    kino_Scorer_skip_to_t       do_skip_to;
    chy_bool_t                  first_time;
};

/* Constructor.
 */
kino_BooleanScorer* 
kino_BoolScorer_new(struct kino_Similarity *sim);

void
kino_BoolScorer_destroy(kino_BooleanScorer *self);
KINO_METHOD("Kino_BoolScorer_Destroy");

chy_bool_t
kino_BoolScorer_next(kino_BooleanScorer *self);
KINO_METHOD("Kino_BoolScorer_Next");

chy_bool_t
kino_BoolScorer_skip_to(kino_BooleanScorer *self, chy_u32_t target);
KINO_METHOD("Kino_BoolScorer_Skip_To");

struct kino_Tally*
kino_BoolScorer_tally(kino_BooleanScorer *self);
KINO_METHOD("Kino_BoolScorer_Tally");

chy_u32_t 
kino_BoolScorer_doc(kino_BooleanScorer *self);
KINO_METHOD("Kino_BoolScorer_Doc");

/* Add a scorer for a sub-query.
 */
void
kino_BoolScorer_add_subscorer(kino_BooleanScorer* self, 
                              kino_Scorer* subscorer, 
                              const struct kino_ByteBuf *occur);
KINO_METHOD("Kino_BoolScorer_Add_Subscorer");

KINO_END_CLASS

#endif /* H_KINO_BOOLEANSCORER */

/* Copyright 2005-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

