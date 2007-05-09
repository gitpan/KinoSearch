#ifndef H_KINO_FIELDDOC
#define H_KINO_FIELDDOC 1

#include "KinoSearch/Search/ScoreDoc.r"

typedef struct kino_FieldDoc kino_FieldDoc;
typedef struct KINO_FIELDDOC_VTABLE KINO_FIELDDOC_VTABLE;

struct kino_FieldDocCollator;

KINO_CLASS("KinoSearch::Search::FieldDoc", "FieldDoc",
    "KinoSearch::Search::ScoreDoc");

struct kino_FieldDoc {
    KINO_FIELDDOC_VTABLE *_;
    KINO_SCOREDOC_MEMBER_VARS;
    struct kino_FieldDocCollator *collator;
};

/* Constructor
 */
kino_FieldDoc*
kino_FieldDoc_new(chy_u32_t doc_num, float score, 
                  struct kino_FieldDocCollator *collator);

void
kino_FieldDoc_destroy(kino_FieldDoc *self);
KINO_METHOD("Kino_FieldDoc_Destroy");

KINO_END_CLASS

#endif /* H_KINO_FIELDDOC */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

