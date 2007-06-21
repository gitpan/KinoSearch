#ifndef H_KINO_MATCHFIELDSCORER
#define H_KINO_MATCHFIELDSCORER 1

#include "KinoSearch/Search/Scorer.r"

typedef struct kino_MatchFieldScorer kino_MatchFieldScorer;
typedef struct KINO_MATCHFIELDSCORER_VTABLE KINO_MATCHFIELDSCORER_VTABLE;

struct kino_Tally;
struct kino_Lexicon;
struct kino_HitCollector;
struct kino_Native;

KINO_CLASS("KinoSearch::Search::MatchFieldScorer", "MatchFieldScorer", 
    "KinoSearch::Search::Scorer");

struct kino_MatchFieldScorer {
    KINO_MATCHFIELDSCORER_VTABLE *_;
    KINO_SCORER_MEMBER_VARS;
    struct kino_Tally    *tally;
    struct kino_IntMap   *sort_cache;
    chy_u32_t             doc_num;
    struct kino_Native   *weight;
};

/* Constructor. 
 */
kino_MatchFieldScorer*
kino_MatchFieldScorer_new(struct kino_Similarity *sim, 
                          struct kino_IntMap *sort_cache,
                          void *weight);

void
kino_MatchFieldScorer_destroy(kino_MatchFieldScorer *self);
KINO_METHOD("Kino_MatchFieldScorer_Destroy");

chy_bool_t
kino_MatchFieldScorer_next(kino_MatchFieldScorer* self);
KINO_METHOD("Kino_MatchFieldScorer_Next");

struct kino_Tally*
kino_MatchFieldScorer_tally(kino_MatchFieldScorer* self);
KINO_METHOD("Kino_MatchFieldScorer_Tally");

chy_u32_t 
kino_MatchFieldScorer_doc(kino_MatchFieldScorer* self);
KINO_METHOD("Kino_MatchFieldScorer_Doc");

KINO_END_CLASS

#endif /* H_KINO_MATCHFIELDSCORER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

