#ifndef H_KINO_PHRASESCORER
#define H_KINO_PHRASESCORER 1

#include "KinoSearch/Search/Scorer.r"

typedef struct kino_PhraseScorer kino_PhraseScorer;
typedef struct KINO_PHRASESCORER_VTABLE KINO_PHRASESCORER_VTABLE;

struct kino_TermDocs;
struct kino_ByteBuf;

KINO_CLASS("KinoSearch::Search::PhraseScorer", "PhraseScorer", 
    "KinoSearch::Search::Scorer");

struct kino_PhraseScorer {
    KINO_PHRASESCORER_VTABLE *_;
    KINO_SCORER_MEMBER_VARS;
    
    kino_u32_t             doc_num;
    kino_u32_t             slop;
    kino_u32_t             num_elements;
    struct kino_TermDocs **term_docs;
    kino_u32_t            *phrase_offsets;
    struct kino_ByteBuf   *anchor_set;
    float                  phrase_freq;
    float                  phrase_boost;
    float                  weight_value;
    kino_bool_t            first_time;
    kino_bool_t            more;
};

/* Constructor
 */
KINO_FUNCTION(
kino_PhraseScorer*
kino_PhraseScorer_new(kino_u32_t num_elements, 
                      struct kino_TermDocs **term_docs, 
                      kino_u32_t *phrase_offsets, float weight_val,
                      struct kino_Similarity *sim, kino_u32_t slop));

KINO_METHOD("Kino_PhraseScorer_Destroy",
void
kino_PhraseScorer_destroy(kino_PhraseScorer*));

KINO_METHOD("Kino_PhraseScorer_Next",
kino_bool_t
kino_PhraseScorer_next(kino_PhraseScorer*));

KINO_METHOD("Kino_PhraseScorer_Skip_To",
kino_bool_t
kino_PhraseScorer_skip_to(kino_PhraseScorer *self, kino_u32_t target));

KINO_METHOD("Kino_PhraseScorer_Doc",
kino_u32_t 
kino_PhraseScorer_doc(kino_PhraseScorer*));

KINO_METHOD("Kino_PhraseScorer_Score",
float
kino_PhraseScorer_score(kino_PhraseScorer*));

/* Calculate how often the phrase occurs in the current document.
 */
KINO_METHOD("Kino_PhraseScorer_Calc_Phrase_Freq",
float
kino_PhraseScorer_calc_phrase_freq(kino_PhraseScorer*));

KINO_END_CLASS

#endif /* H_KINO_PHRASESCORER */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

