#ifndef H_KINO_PHRASESCORER
#define H_KINO_PHRASESCORER 1

#include "KinoSearch/Search/Scorer.r"

typedef struct kino_PhraseScorer kino_PhraseScorer;
typedef struct KINO_PHRASESCORER_VTABLE KINO_PHRASESCORER_VTABLE;

struct kino_Tally;
struct kino_ByteBuf;
struct kino_Int;
struct kino_PostingList;

KINO_CLASS("KinoSearch::Search::PhraseScorer", "PhraseScorer", 
    "KinoSearch::Search::Scorer");

struct kino_PhraseScorer {
    KINO_PHRASESCORER_VTABLE *_;
    KINO_SCORER_MEMBER_VARS;
    chy_u32_t                  doc_num;
    chy_u32_t                  slop;
    chy_u32_t                  num_elements;
    struct kino_Tally         *tally;
    struct kino_PostingList  **plists;
    chy_u32_t                 *phrase_offsets;
    struct kino_ByteBuf       *anchor_set;
    struct kino_ByteBuf       *raw_prox_bb;
    float                      phrase_freq;
    float                      phrase_boost;
    void                      *weight_ref;
    float                      weight_value;
    chy_bool_t                 first_time;
    chy_bool_t                 more;
};

/* Constructor
 */
kino_PhraseScorer*
kino_PhraseScorer_new(struct kino_Similarity *sim,
                      struct kino_VArray *plists, 
                      struct kino_VArray *phrase_offsets,
                      void *weight_ref, float weight_val,
                      chy_u32_t slop);

void
kino_PhraseScorer_destroy(kino_PhraseScorer *self);
KINO_METHOD("Kino_PhraseScorer_Destroy");

chy_bool_t
kino_PhraseScorer_next(kino_PhraseScorer *self);
KINO_METHOD("Kino_PhraseScorer_Next");

chy_bool_t
kino_PhraseScorer_skip_to(kino_PhraseScorer *self, chy_u32_t target);
KINO_METHOD("Kino_PhraseScorer_Skip_To");

chy_u32_t 
kino_PhraseScorer_doc(kino_PhraseScorer *self);
KINO_METHOD("Kino_PhraseScorer_Doc");

struct kino_Tally*
kino_PhraseScorer_tally(kino_PhraseScorer *self);
KINO_METHOD("Kino_PhraseScorer_Tally");

/* Calculate how often the phrase occurs in the current document.
 */
float
kino_PhraseScorer_calc_phrase_freq(kino_PhraseScorer *self);
KINO_METHOD("Kino_PhraseScorer_Calc_Phrase_Freq");

KINO_END_CLASS

#endif /* H_KINO_PHRASESCORER */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

