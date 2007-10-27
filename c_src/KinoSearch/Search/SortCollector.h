#ifndef H_KINO_SORTCOLLECTOR
#define H_KINO_SORTCOLLECTOR 1

#include "KinoSearch/Search/TopDocCollector.r"

typedef struct kino_SortCollector kino_SortCollector;
typedef struct KINO_SORTCOLLECTOR_VTABLE KINO_SORTCOLLECTOR_VTABLE;

struct kino_FieldDocCollator;

KINO_CLASS("KinoSearch::Search::SortCollector", "SortColl", 
    "KinoSearch::Search::TopDocCollector");

struct kino_SortCollector {
    KINO_SORTCOLLECTOR_VTABLE *_;
    KINO_TOPDOCCOLLECTOR_MEMBER_VARS;
    struct kino_FieldDocCollator *collator;
    chy_i32_t                     min_doc;
};

/* Constructor.  
 */
kino_SortCollector *
kino_SortColl_new(struct kino_FieldDocCollator *collator, 
                  chy_u32_t num_hits);

void
kino_SortColl_destroy(kino_SortCollector *self);
KINO_METHOD("Kino_SortColl_Destroy");

KINO_END_CLASS

#endif /* H_KINO_SORTCOLLECTOR */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

