/**
 * @class KinoSearch::Search::ScoreProx ScoreProx.r
 * @brief Positions which matched a document
 *
 * A ScoreProx object contains an ordered array of positions from one field
 * which matched the document currently being scored.
 * 
 * The positions array is not owned by the ScoreProx object, so the parent
 * object must take responsibility for cleaning it up.
 */

#ifndef H_KINO_SCOREPROX
#define H_KINO_SCOREPROX 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_ScoreProx kino_ScoreProx;
typedef struct KINO_SCOREPROX_VTABLE KINO_SCOREPROX_VTABLE;

KINO_CLASS("KinoSearch::Search::ScoreProx", "ScoreProx", 
    "KinoSearch::Util::Obj");

struct kino_ScoreProx {
    KINO_SCOREPROX_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    chy_i32_t               field_num;
    chy_u32_t               num_prox;
    chy_u32_t              *prox;
};

/* Constructor.
 */
kino_ScoreProx*
kino_ScoreProx_new();

KINO_END_CLASS

#endif /* H_KINO_SCOREPROX */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

