#ifndef H_KINO_SCOREDOC
#define H_KINO_SCOREDOC 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_ScoreDoc kino_ScoreDoc;
typedef struct KINO_SCOREDOC_VTABLE KINO_SCOREDOC_VTABLE;

struct kino_ByteBuf;
struct kino_ViewByteBuf;

KINO_CLASS("KinoSearch::Search::ScoreDoc", "ScoreDoc",
    "KinoSearch::Util::Obj");

struct kino_ScoreDoc {
    KINO_SCOREDOC_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    kino_u32_t    id;
    float         score;
};

/* Constructor
 */
KINO_FUNCTION(
kino_ScoreDoc*
kino_ScoreDoc_new(kino_u32_t id, float score));

KINO_FUNCTION(
kino_ScoreDoc*
kino_ScoreDoc_deserialize(struct kino_ViewByteBuf *serialized));

KINO_METHOD("Kino_ScoreDoc_Serialize",
void
kino_ScoreDoc_serialize(kino_ScoreDoc *self, struct kino_ByteBuf *target));

KINO_END_CLASS

#endif /* H_KINO_SCOREDOC */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

