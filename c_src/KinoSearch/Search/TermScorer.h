/** 
 * @class KinoSearch::Search::TermScorer TermScorer.r
 * @brief Base class for TermScorers.
 * 
 * Each subclass of Posting is associated with a corresponding subclass of
 * TermScorer.
 */
#ifndef H_KINO_TERMSCORER
#define H_KINO_TERMSCORER 1

#include "KinoSearch/Search/Scorer.r"

typedef struct kino_TermScorer kino_TermScorer;
typedef struct KINO_TERMSCORER_VTABLE KINO_TERMSCORER_VTABLE;

struct kino_Tally;
struct kino_ScoreProx;
struct kino_Posting;
struct kino_PostingList;
struct kino_HitCollector;
struct kino_Native;

#define KINO_TERMSCORER_SCORE_CACHE_SIZE 32
#ifdef KINO_USE_SHORT_NAMES
  #define TERMSCORER_SCORE_CACHE_SIZE KINO_TERMSCORER_SCORE_CACHE_SIZE
#endif

KINO_CLASS("KinoSearch::Search::TermScorer", "TermScorer", 
    "KinoSearch::Search::Scorer");

struct kino_TermScorer {
    KINO_TERMSCORER_VTABLE *_;
    KINO_SCORER_MEMBER_VARS;
    float                     weight_value;
    float                    *score_cache;
    struct kino_Native       *weight;
    struct kino_Tally        *tally;
    struct kino_ScoreProx    *sprox;
    struct kino_PostingList  *plist;
    struct kino_ByteBuf      *postings;
    struct kino_Posting      *posting;
};

void
kino_TermScorer_destroy(kino_TermScorer *self);
KINO_METHOD("Kino_TermScorer_Destroy");

chy_bool_t
kino_TermScorer_next(kino_TermScorer* self);
KINO_METHOD("Kino_TermScorer_Next");

chy_bool_t
kino_TermScorer_skip_to(kino_TermScorer* self, chy_u32_t target);
KINO_METHOD("Kino_TermScorer_Skip_To");

chy_u32_t 
kino_TermScorer_doc(kino_TermScorer* self);
KINO_METHOD("Kino_TermScorer_Doc");

struct kino_Tally*
kino_TermScorer_tally(kino_TermScorer* self);
KINO_METHOD("Kino_TermScorer_Tally");

KINO_END_CLASS

#endif /* H_KINO_TERMSCORER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

