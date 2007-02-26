#ifndef H_KINO_HITQUEUE
#define H_KINO_HITQUEUE 1

#include "KinoSearch/Util/PriorityQueue.r"

typedef struct kino_HitQueue kino_HitQueue;
typedef struct KINO_HITQUEUE_VTABLE KINO_HITQUEUE_VTABLE;

KINO_CLASS("KinoSearch::Search::HitQueue", "HitQ", 
    "KinoSearch::Util::PriorityQueue");

struct kino_HitQueue {
    KINO_HITQUEUE_VTABLE *_;
    kino_u32_t refcount;
    KINO_PRIORITYQUEUE_MEMBER_VARS
};

KINO_FUNCTION(
kino_HitQueue*
kino_HitQ_new(kino_u32_t max_size));

KINO_END_CLASS

#endif /* H_KINO_HITQUEUE */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

