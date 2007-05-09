#ifndef H_KINO_SORTEDHITQUEUE
#define H_KINO_SORTEDHITQUEUE 1

#include "KinoSearch/Search/HitQueue.r"

typedef struct kino_SortedHitQueue kino_SortedHitQueue;
typedef struct KINO_SORTEDHITQUEUE_VTABLE KINO_SORTEDHITQUEUE_VTABLE;

KINO_CLASS("KinoSearch::Search::SortedHitQueue", "SortedHitQ", 
    "KinoSearch::Search::HitQueue");

struct kino_SortedHitQueue {
    KINO_SORTEDHITQUEUE_VTABLE *_;
    KINO_HITQUEUE_MEMBER_VARS;
};

kino_SortedHitQueue*
kino_SortedHitQ_new(chy_u32_t max_size);

KINO_END_CLASS

#endif /* H_KINO_HITQUEUE */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

