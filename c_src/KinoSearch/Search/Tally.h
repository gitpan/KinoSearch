/**
 * @class KinoSearch::Search::Tally
 * @brief Scoring info regarding a single document.
 *
 * A Tally is a struct which encapsulates scoring information.  It "belongs"
 * to a particular Scorer.  Other entities may access a Tally's Member's
 * directly, they may not edit them.
 *
 * As a minimum, a Tally returned by a Scorer contains a single aggregate
 * score.  If appropriate, an arrays of positions is also present,  with
 * [num_prox] indicating the number of elements in the array.
 *
 * Existing Tally objects become invalid as soon as Scorer_Next() is called.
 */

#ifndef H_KINO_TALLY
#define H_KINO_TALLY 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_Tally kino_Tally;
typedef struct KINO_TALLY_VTABLE KINO_TALLY_VTABLE;

struct kino_ByteBuf;
struct kino_Term;
struct kino_Lexicon;

KINO_CLASS("KinoSearch::Search::Tally", "Tally", 
    "KinoSearch::Util::Obj");

struct kino_Tally {
    KINO_TALLY_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    float                   score;
    chy_u32_t               num_matchers;
    chy_u32_t               num_prox;
    chy_u32_t              *prox;
};

/* Constructor.
 */
kino_Tally*
kino_Tally_new();

KINO_END_CLASS

#endif /* H_KINO_TALLY */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

