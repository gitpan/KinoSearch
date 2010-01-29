#define C_KINO_BBSORTEX
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test/Util/BBSortEx.h"

#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/OutStream.h"

BBSortEx*
BBSortEx_new(u32_t mem_threshold, VArray *external)
{
    BBSortEx *self = (BBSortEx*)VTable_Make_Obj(BBSORTEX);
    return BBSortEx_init(self, mem_threshold, external);
}

BBSortEx*
BBSortEx_init(BBSortEx *self, u32_t mem_threshold, VArray *external)
{
    SortEx_init((SortExternal*)self, mem_threshold);
    self->external_tick = 0;
    self->external = (VArray*)INCREF(external);
    return self;
}

void
BBSortEx_destroy(BBSortEx *self) 
{
    DECREF(self->external);
    SUPER_DESTROY(self, BBSORTEX);
}

void
BBSortEx_feed(BBSortEx *self, Obj *item)
{
    SortEx_feed((SortExternal*)self, item);

    /* Flush() if necessary. */
    ByteBuf *bytebuf = (ByteBuf*)CERTIFY(item, BYTEBUF);
    self->mem_consumed += BB_Get_Size(bytebuf);
    if (self->mem_consumed >= self->mem_thresh) {
        BBSortEx_Flush(self);
    }
}

void
BBSortEx_flush(BBSortEx *self)
{
    u32_t        cache_count = self->cache_max - self->cache_tick;
    VArray      *elems;
    BBSortEx    *run;
    u32_t        i;

    if (!cache_count) return;
    else elems = VA_new(cache_count);

    /* Sort, then create a new run. */
    BBSortEx_Sort_Cache(self);
    for (i = self->cache_tick; i < self->cache_max; i++) {
        VA_Push(elems, self->cache[i]);
    }
    run = BBSortEx_new(0, elems);
    DECREF(elems);
    BBSortEx_Add_Run(self, (SortExternal*)run);

    /* Blank the cache vars. */
    self->cache_tick += cache_count;
    BBSortEx_Clear_Cache(self);
}

void
BBSortEx_flip(BBSortEx *self)
{
    u32_t i;
    u32_t run_mem_thresh = 65536;

    BBSortEx_Flush(self);

    /* Recalculate the approximate mem allowed for each run. */
    u32_t num_runs = VA_Get_Size(self->runs);
    if (num_runs) {
        run_mem_thresh = (self->mem_thresh / 2) / num_runs;
        if (run_mem_thresh < 65536)
            run_mem_thresh = 65536;
    }

    for (i = 0; i < num_runs; i++) {
        BBSortEx *run = (BBSortEx*)VA_Fetch(self->runs, i);
        BBSortEx_Set_Mem_Thresh(run, run_mem_thresh);
    }

    /* OK to fetch now. */
    self->flipped = true;
}

int
BBSortEx_compare(BBSortEx *self, Obj **a, Obj **b)
{
    UNUSED_VAR(self);
    return BB_compare( (ByteBuf**)a, (ByteBuf**)b );
}

Obj*
BBSortEx_recover_item(BBSortEx *self)
{
    if (self->mem_consumed >= self->mem_thresh) {
        self->mem_consumed = 0;
        return NULL;
    }
    else if (self->external_tick >= VA_Get_Size(self->external)) {
        return NULL;
    }
    else {
        ByteBuf *retval 
            = (ByteBuf*)VA_Fetch(self->external, self->external_tick);
        self->external_tick++;
        /* Should be + sizeof(ByteBuf), but that's ok. */
        self->mem_consumed += BB_Get_Size(retval); 
        return INCREF(retval);
    }
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

