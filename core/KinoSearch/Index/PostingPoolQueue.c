#define C_KINO_POSTINGPOOLQUEUE
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
        = (PostingPoolQueue*)VTable_Make_Obj(POSTINGPOOLQUEUE);
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
        PostPool_compare_raw_postings);

    /* Assign. */
    for (i = 0; i < num_post_pools; i++) {
        PostingPool *post_pool = (PostingPool*)VA_Fetch(post_pools, i);
        if (post_pool != NULL) {
            if (OBJ_IS_A(post_pool, MERGEPOSTINGPOOL)) {
                MergePostPool_Set_Mem_Thresh(post_pool, sub_thresh);
            }
            else if (OBJ_IS_A(post_pool, FRESHPOSTINGPOOL)) {
                FreshPostPool_Flip(post_pool, lex_instream, post_instream,
                    sub_thresh);
            }
            PostPoolQ_Add_Run(self, (SortExRun*)post_pool);
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

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

