#ifndef H_KINO_TOPDOCCOLLECTOR
#define H_KINO_TOPDOCCOLLECTOR 1

#include "KinoSearch/Search/HitCollector.r"

struct kino_HitQueue;

typedef struct kino_TopDocCollector kino_TopDocCollector;
typedef struct KINO_TOPDOCCOLLECTOR_VTABLE KINO_TOPDOCCOLLECTOR_VTABLE;

struct kino_HitQueue;

KINO_CLASS("KinoSearch::Search::TopDocCollector", "TDColl", 
    "KinoSearch::Search::HitCollector");

struct kino_TopDocCollector {
    KINO_TOPDOCCOLLECTOR_VTABLE *_;
    kino_u32_t refcount;
    KINO_HITCOLLECTOR_MEMBER_VARS
    float                   min_score;
    kino_u32_t              num_hits;
    kino_u32_t              total_hits;
    struct kino_HitQueue   *hit_q;
};

/* Constructor. 
 */
KINO_FUNCTION(
kino_TopDocCollector* 
kino_TDColl_new(kino_u32_t num_hits));

KINO_METHOD("Kino_TDColl_Destroy",
void
kino_TDColl_destroy(kino_TopDocCollector *self));

KINO_END_CLASS

#endif /* H_KINO_TOPDOCCOLLECTOR */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

