#ifndef H_KINO_BOOLEANSCORER
#define H_KINO_BOOLEANSCORER 1

#include "KinoSearch/Search/Scorer.r"

struct kino_Similarity;

typedef struct kino_BooleanScorer kino_BooleanScorer;
typedef struct KINO_BOOLEANSCORER_VTABLE KINO_BOOLEANSCORER_VTABLE;

/* A MatchBatch holds scoring data for up to 2048 documents.  
 */
typedef struct kino_MatchBatch kino_MatchBatch;

/* A BoolSubScorer wraps a scorer for a clause within a BooleanQuery.
 */
typedef struct kino_BoolSubScorer kino_BoolSubScorer;

#ifdef KINO_USE_SHORT_NAMES
  #define MatchBatch kino_MatchBatch
  #define BoolSubScorer kino_BoolSubScorer
#endif

KINO_CLASS("KinoSearch::Search::BooleanScorer", "BoolScorer", 
    "KinoSearch::Search::Scorer");

struct kino_BooleanScorer {
    KINO_BOOLEANSCORER_VTABLE *_;
    kino_u32_t refcount;
    KINO_SCORER_MEMBER_VARS

    kino_u32_t          doc_num;
    kino_u32_t          end;
    kino_u32_t          max_coord;
    float              *coord_factors;
    kino_u32_t          required_mask;
    kino_u32_t          prohibited_mask;
    kino_u32_t          next_mask;
    kino_MatchBatch    *mbatch;
    kino_BoolSubScorer *subscorers; /* linked list */
};

/* Constructor.
 */
KINO_FUNCTION(
kino_BooleanScorer* 
kino_BoolScorer_new(struct kino_Similarity *sim));

KINO_METHOD("Kino_BoolScorer_Destroy",
void
kino_BoolScorer_destroy(kino_BooleanScorer *self));

KINO_METHOD("Kino_BoolScorer_Next",
kino_bool_t
kino_BoolScorer_next(kino_BooleanScorer *self));

KINO_METHOD("Kino_BoolScorer_Score",
float
kino_BoolScorer_score(kino_BooleanScorer *self));

KINO_METHOD("Kino_BoolScorer_Doc",
kino_u32_t 
kino_BoolScorer_doc(kino_BooleanScorer *self));

/* Add a scorer for a sub-query of the BooleanQuery.
 */
KINO_METHOD("Kino_BoolScorer_Add_Subscorer",
void
kino_BoolScorer_add_subscorer(kino_BooleanScorer* self, 
                              kino_Scorer* subscorer, char *occur));

KINO_END_CLASS

#endif /* H_KINO_BOOLEANSCORER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

