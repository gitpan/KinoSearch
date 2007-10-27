#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_BBSORTEX_VTABLE
#include "KinoSearch/Util/BBSortEx.r"

#include "KinoSearch/Util/BBSortExRun.r"

#include "KinoSearch/InvIndex.r"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/OutStream.r"

/* Transfer all current cache elements to a new run, but don't flush to disk
 * yet.
 */
static BBSortExRun*
offload_new_run(BBSortEx *self);

BBSortEx*
BBSortEx_new(InvIndex *invindex, SegInfo *seg_info, u32_t mem_threshold)
{
    CREATE(self, BBSortEx, BBSORTEX);

    /* init */
    kino_SortEx_init_base((SortExternal*)self, mem_threshold, 
        BBSortEx_compare_bbs);
    self->outstream       = NULL;
    self->instream        = NULL;

    /* assign */
    self->invindex        = REFCOUNT_INC(invindex);
    self->seg_info        = REFCOUNT_INC(seg_info);

    /* derive */
    self->sortfile_name = BB_CLONE(self->seg_info->seg_name);
    BB_Cat_Str(self->sortfile_name, ".srt", 4);
    
    return self;
}

int 
BBSortEx_compare_bbs(void *context, const void *va, const void *vb) 
{
    UNUSED_VAR(context);
    return BB_compare(va, vb);
}

void
BBSortEx_destroy(BBSortEx *self) 
{
    /* free individual members */
    REFCOUNT_DEC(self->invindex);
    REFCOUNT_DEC(self->outstream);
    REFCOUNT_DEC(self->instream);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->sortfile_name);

    /* SUPER::DESTROY */
    kino_SortEx_destroy((SortExternal*)self);
}

void
BBSortEx_feed_str(BBSortEx *self, char  *ptr, u32_t len) 
{
    ByteBuf *const bb = BB_new_str(ptr, len);
    BBSortEx_Feed(self, (Obj*)bb, bb->len + sizeof(ByteBuf));
    REFCOUNT_DEC(bb);
}

void
BBSortEx_flush(BBSortEx *self)
{
    BBSortExRun *run = offload_new_run(self);

    /* lazily open outstream */
    if (self->outstream == NULL) {
        ByteBuf *sortfile_name = BB_CLONE(self->seg_info->seg_name);
        BB_Cat_Str(sortfile_name, ".srt", 4);
        self->outstream = Folder_Open_OutStream(self->invindex->folder, 
            sortfile_name); 
        REFCOUNT_DEC(sortfile_name);
    }

    BBSortExRun_Flush(run, self->outstream);
    BBSortEx_Add_Run(self, (SortExRun*)run);
    REFCOUNT_DEC(run);
}

static BBSortExRun*
offload_new_run(BBSortEx *self)
{
    Obj        **cache_elems = self->cache + self->cache_tick;
    u32_t        cache_count = self->cache_max - self->cache_tick;
    BBSortExRun *run;

    /* sanity check */
    if (cache_count == 0)
        CONFESS("Can't create new run if cache is empty");

    /* sort, then create a new run */
    BBSortEx_Sort_Cache(self);
    run = BBSortExRun_new(cache_elems, cache_count);

    /* blank the cache vars */
    self->cache_tick += cache_count;
    SortEx_Clear_Cache(self);

    return run;
}

void
BBSortEx_flip(BBSortEx *self)
{
    u32_t i;
    u32_t run_mem_thresh = 65536;

    /* only create instream if existing runs have been flushed to disk */
    if (self->outstream != NULL) {
        /* close outstream */
        OutStream_SClose(self->outstream);
        REFCOUNT_DEC(self->outstream);
        self->outstream = NULL;

        /* get instream */
        self->instream = Folder_Open_InStream(self->invindex->folder,
            self->sortfile_name);
    }

    /* recalculate the approximate mem allowed for each run */
    if (self->num_runs) {
        run_mem_thresh = (self->mem_thresh / 2) / self->num_runs;
        if (run_mem_thresh < 65536)
            run_mem_thresh = 65536;
    }

    for (i = 0; i < self->num_runs; i++) {
        BBSortExRun_Flip(self->runs[i], self->instream, run_mem_thresh);
    }

    /* move current cache elements to a run, if there are any */
    if (self->cache_tick < self->cache_max) {
        BBSortExRun *run = offload_new_run(self);
        BBSortEx_Add_Run(self, (SortExRun*)run);
        REFCOUNT_DEC(run);
    }

    /* ok to fetch now */
    self->flipped = true;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

