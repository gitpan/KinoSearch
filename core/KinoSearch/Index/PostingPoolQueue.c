#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/PostingPoolQueue.h"
#include "KinoSearch/Index/PostingPool.h"
#include "KinoSearch/Posting/RawPosting.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Util/I32Array.h"

#define DOESNT_MATTER 1024

PostingPoolQueue*
PostPoolQ_new(VArray *post_pools, InStream *lex_instream, 
              InStream *post_instream, u32_t mem_thresh)
{
    PostingPoolQueue *self 
        = (PostingPoolQueue*)VTable_Make_Obj(&POSTINGPOOLQUEUE);
    return PostPoolQ_init(self, post_pools, lex_instream, post_instream, 
        mem_thresh);
}

PostingPoolQueue*
PostPoolQ_init(PostingPoolQueue *self, VArray *post_pools, 
               InStream *lex_instream, InStream *post_instream, 
               u32_t mem_thresh)
{
    u32_t i;
    u32_t num_post_pools = VA_Get_Size(post_pools);
    u32_t sub_thresh = num_post_pools > 0 
        ? mem_thresh / num_post_pools 
        : mem_thresh;

    /* Init. */
    SortEx_init((SortExternal*)self, DOESNT_MATTER,
        PostPoolQ_compare_rawp);

    /* Assign. */
    for (i = 0; i < num_post_pools; i++) {
        PostingPool *post_pool = (PostingPool*)VA_Fetch(post_pools, i);
        if (post_pool != NULL) {
            PostPoolQ_Add_Run(self, (SortExRun*)post_pool);
            PostPool_Flip(post_pool, lex_instream, post_instream, sub_thresh);
        }
    }

    /* Always in read mode. */
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
        /* If a is a substring of b, it's less than b, so return a neg num. */
        if (len > 0)
            comparison = a_len - b_len;

        /* Break ties by doc id. */
        if (comparison == 0) 
            comparison = a->doc_id - b->doc_id;
    }

    return comparison;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

