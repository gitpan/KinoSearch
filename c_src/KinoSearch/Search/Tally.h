/**
 * @class KinoSearch::Search::Tally
 * @brief Scoring info regarding a single document.
 *
 * A Tally is a struct which encapsulates scoring information.  It "belongs"
 * to a particular Scorer.  Other entities may access a Tally's Member's
 * directly, they may not edit them.
 *
 * As a minimum, a Tally returned by a Scorer contains a single aggregate
 * score. It will also have one or more ScoreProx objects indicating which
 * positions matched the current document, sorted by field number.  
 *
 * Existing Tally objects become invalid as soon as Scorer_Next() is called.
 */

#ifndef H_KINO_TALLY
#define H_KINO_TALLY 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_Tally kino_Tally;
typedef struct KINO_TALLY_VTABLE KINO_TALLY_VTABLE;

struct kino_ScoreProx;

KINO_FINAL_CLASS("KinoSearch::Search::Tally", "Tally", 
    "KinoSearch::Util::Obj");

struct kino_Tally {
    KINO_TALLY_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    float                   score;
    chy_u32_t               num_matchers;
    chy_u32_t               sprox_cap;
    chy_u32_t               num_sproxen;
    struct kino_ScoreProx **sproxen;
};

/* Constructor.
 */
kino_Tally*
kino_Tally_new();

/* Add a ScoreProx object to the Tally.  The ScoreProx will not have its
 * refcount affected, so the caller is responsible for cleanup.
 */
void
kino_Tally_add_sprox(kino_Tally *self, struct kino_ScoreProx *sprox);
KINO_METHOD("Kino_Tally_Add_SProx");

/* Purge all ScoreProx objects.
 */
void
kino_Tally_zap_sproxen(kino_Tally *self);
KINO_METHOD("Kino_Tally_Zap_SProxen");

void
kino_Tally_destroy(kino_Tally *self);
KINO_METHOD("Kino_Tally_Destroy");

KINO_END_CLASS

#endif /* H_KINO_TALLY */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

