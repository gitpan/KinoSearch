/**
 * @class KinoSearch::Index::PostingPoolQueue PostingPoolQueue.r
 * @brief External sorter for raw postings.
 */
#ifndef H_KINO_POSTINGPOOLQUEUE
#define H_KINO_POSTINGPOOLQUEUE 1

#include "KinoSearch/Util/SortExternal.r"

struct kino_PostingPool;
struct kino_IntMap;

typedef struct kino_PostingPoolQueue kino_PostingPoolQueue;
typedef struct KINO_POSTINGPOOLQUEUE_VTABLE KINO_POSTINGPOOLQUEUE_VTABLE;

KINO_FINAL_CLASS("KinoSearch::Util::PostingPoolQueue", "PostPoolQ", 
    "KinoSearch::Util::SortExternal");

struct kino_PostingPoolQueue {
    KINO_POSTINGPOOLQUEUE_VTABLE *_;
    KINO_SORTEXTERNAL_MEMBER_VARS;
};

/* Constructor.
 */
kino_PostingPoolQueue*
kino_PostPoolQ_new(struct kino_VArray *post_pools,
                   struct kino_InStream *lex_instream,
                   struct kino_InStream *post_stream,
                   struct kino_IntMap *pre_sort_map,
                   chy_u32_t mem_thresh);

/* Compare two RawPosting** pointers.
 */
int
kino_PostPoolQ_compare_rawp(void *context, const void *va, const void *vb);

/* Compare two RawPosting** pointers, using a remapped doc number from an
 * IntMap supplied as [context].
 */
int
kino_PostPoolQ_compare_rawp_for_pre_sort(void *context, 
                                         const void *va, const void *vb);

void
kino_PostPoolQ_flip(kino_PostingPoolQueue *self);
KINO_METHOD("Kino_PostPoolQ_Flip");

KINO_END_CLASS

#endif /* H_KINO_POSTINGPOOLQUEUE */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

