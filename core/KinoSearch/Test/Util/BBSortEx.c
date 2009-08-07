#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test/Util/BBSortEx.h"
#include "KinoSearch/Test/Util/BBSortExRun.h"

#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/OutStream.h"

BBSortEx*
BBSortEx_init(BBSortEx *self, u32_t mem_threshold)
{
    SortEx_init((SortExternal*)self, mem_threshold, 
        BBSortEx_compare_bbs);
    return self;
}

int 
BBSortEx_compare_bbs(void *context, const void *va, const void *vb) 
{
    UNUSED_VAR(context);
    return BB_compare(va, vb);
}

void
BBSortEx_flush(BBSortEx *self)
{
    u32_t        cache_count = self->cache_max - self->cache_tick;
    VArray      *elems;
    BBSortExRun *run;
    u32_t        i;

    if (!cache_count) return;
    else elems = VA_new(cache_count);

    /* Sort, then create a new run. */
    BBSortEx_Sort_Cache(self);
    for (i = self->cache_tick; i < self->cache_max; i++) {
        VA_Push(elems, self->cache[i]);
    }
    run = BBSortExRun_new(elems);
    DECREF(elems);
    BBSortEx_Add_Run(self, (SortExRun*)run);
    DECREF(run);

    /* Blank the cache vars. */
    self->cache_tick += cache_count;
    SortEx_Clear_Cache(self);
}

void
BBSortEx_flip(BBSortEx *self)
{
    u32_t i;
    u32_t run_mem_thresh = 65536;

    BBSortEx_Flush(self);

    /* Recalculate the approximate mem allowed for each run. */
    if (self->num_runs) {
        run_mem_thresh = (self->mem_thresh / 2) / self->num_runs;
        if (run_mem_thresh < 65536)
            run_mem_thresh = 65536;
    }

    for (i = 0; i < self->num_runs; i++) {
        BBSortExRun_Set_Mem_Thresh(self->runs[i], run_mem_thresh);
    }

    /* OK to fetch now. */
    self->flipped = true;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

