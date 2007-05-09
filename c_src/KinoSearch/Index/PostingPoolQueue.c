#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_POSTINGPOOLQUEUE_VTABLE
#include "KinoSearch/Index/PostingPoolQueue.r"

#include "KinoSearch/Index/PostingPool.r"
#include "KinoSearch/Posting/RawPosting.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Util/IntMap.r"

#define DOESNT_MATTER 1024

PostingPoolQueue*
PostPoolQ_new(VArray *post_pools, InStream *lex_instream,
              InStream *post_instream, IntMap *pre_sort_map, u32_t mem_thresh)
{
    MSort_compare_t compare = pre_sort_map == NULL 
        ? PostPoolQ_compare_rawp
        : PostPoolQ_compare_rawp_for_pre_sort;
    u32_t i;
    u32_t sub_thresh = post_pools->size > 0 
        ? mem_thresh / post_pools->size 
        : mem_thresh;
    CREATE(self, PostingPoolQueue, POSTINGPOOLQUEUE);

    /* init */
    kino_SortEx_init_base((SortExternal*)self, DOESNT_MATTER, compare);

    /* assign */
    for (i = 0; i < post_pools->size; i++) {
        PostingPool *post_pool = (PostingPool*)VA_Fetch(post_pools, i);
        if (post_pool != NULL) {
            PostPoolQ_Add_Run(self, (SortExRun*)post_pool);
            PostPool_Flip(post_pool, lex_instream, post_instream, sub_thresh);
        }
    }
    if (pre_sort_map != NULL) {
        REFCOUNT_INC(pre_sort_map);
        self->context = (Obj*)pre_sort_map;
    }

    /* always in read mode */
    self->flipped = true;

    return self;
}

void
PostPoolQ_flip(PostingPoolQueue *self)
{
    self->flipped = true;
}

int
PostPoolQ_compare_rawp(void *context, const void *va, const void *vb)
{
    RawPosting *const a = *(RawPosting**)va;
    RawPosting *const b = *(RawPosting**)vb;
    const size_t a_len = a->content_len;
    const size_t b_len = b->content_len;
    const size_t len = a_len < b_len? a_len : b_len;
    int comparison = memcmp(a->blob, b->blob, len);

    UNUSED_VAR(context);

    if (comparison == 0) {
        /* if a is a substring of b, it's less than b, so return a neg num */
        if (len > 0)
            comparison = a_len - b_len;

        /* break ties by doc num */
        if (comparison == 0) 
            comparison = a->doc_num - b->doc_num;
    }

    return comparison;
}

int
PostPoolQ_compare_rawp_for_pre_sort(void *context, 
                                    const void *va, const void *vb)
{
    RawPosting *const a = *(RawPosting**)va;
    RawPosting *const b = *(RawPosting**)vb;
    const size_t a_len = a->content_len;
    const size_t b_len = b->content_len;
    const size_t len = a_len < b_len? a_len : b_len;
    int comparison = memcmp(a->blob, b->blob, len);

    UNUSED_VAR(context);

    if (comparison == 0) {
        /* if a is a substring of b, it's less than b, so return a neg num */
        if (len > 0)
            comparison = a_len - b_len;

        /* break ties by doc num */
        if (comparison == 0) {  /* only difference is here */
            IntMap *const doc_remap = (IntMap*)context;
            const u32_t doc_num_a = IntMap_Get(doc_remap, a->doc_num);
            const u32_t doc_num_b = IntMap_Get(doc_remap, b->doc_num);
            comparison = doc_num_a - doc_num_b;
        }
    }

    return comparison;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

