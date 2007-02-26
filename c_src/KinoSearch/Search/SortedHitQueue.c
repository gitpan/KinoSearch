#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SORTEDHITQUEUE_VTABLE
#include "KinoSearch/Search/SortedHitQueue.r"

#include "KinoSearch/Search/FieldDocCollator.r"

/* Decrement the refcount of a FieldDoc.
 */
static void
SortedHitQ_free_elem(void *elem);

SortedHitQueue*
SortedHitQ_new(u32_t max_size) 
{
    CREATE(self, SortedHitQueue, SORTEDHITQUEUE);
    PriQ_init_base((PriorityQueue*)self, max_size, FDocCollator_less_than, 
        SortedHitQ_free_elem);
    return self;
}

static void
SortedHitQ_free_elem(void *elem) 
{
    REFCOUNT_DEC((Obj*)elem);
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

