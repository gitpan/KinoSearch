#ifndef H_KINO_TERMSCORER
#define H_KINO_TERMSCORER 1

#include "KinoSearch/Search/Scorer.r"

typedef struct kino_TermScorer kino_TermScorer;
typedef struct KINO_TERMSCORER_VTABLE KINO_TERMSCORER_VTABLE;

struct kino_TermDocs;
struct kino_HitCollector;

#define KINO_SCORE_CACHE_SIZE 32
#define KINO_TERM_SCORER_SENTINEL 0xFFFFFFFF

KINO_CLASS("KinoSearch::Search::TermScorer", "TermScorer", 
    "KinoSearch::Search::Scorer");

struct kino_TermScorer {
    KINO_TERMSCORER_VTABLE *_;
    KINO_SCORER_MEMBER_VARS;
    kino_u32_t            doc_num;
    struct kino_TermDocs* term_docs;
    kino_u32_t            pointer;
    kino_u32_t            pointer_max;
    float                 weight_value;
    float                *score_cache;
    kino_u32_t           *doc_nums;
    kino_u32_t           *freqs;
    float                *boosts;
    struct kino_ByteBuf  *doc_nums_bb;
    struct kino_ByteBuf  *field_boosts_bb;
    struct kino_ByteBuf  *freqs_bb;
    struct kino_ByteBuf  *boosts_bb;
    struct kino_ByteBuf  *pos_boosts_bb;
    void                 *weight_ref;
};

/* Constructor. 
 */
KINO_FUNCTION(
kino_TermScorer*
kino_TermScorer_new(struct kino_Similarity *sim));

/* Build up a cache of scores for common (i.e. low) freqs, so they don't have
 * to be continually recalculated.
 */
KINO_FUNCTION(
void
kino_TermScorer_fill_score_cache(kino_TermScorer *self));

KINO_METHOD("Kino_TermScorer_Destroy",
void
kino_TermScorer_destroy(kino_TermScorer *self));

KINO_METHOD("Kino_TermScorer_Next",
kino_bool_t
kino_TermScorer_next(kino_TermScorer* self));

KINO_METHOD("Kino_TermScorer_Score",
float
kino_TermScorer_score(kino_TermScorer* self));

KINO_METHOD("Kino_TermScorer_Doc",
kino_u32_t 
kino_TermScorer_doc(kino_TermScorer* self));

KINO_END_CLASS

#endif /* H_KINO_TERMSCORER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

