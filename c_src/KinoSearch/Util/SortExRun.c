#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SORTEXRUN_VTABLE
#include "KinoSearch/Util/SortExRun.r"

void
SortExRun_init_base(SortExRun *self, MSort_compare_t compare)
{
    /* init */
    self->cache        = NULL;
    self->cache_cap    = 0;
    self->cache_max    = 0;
    self->cache_tick   = 0;
    self->slice_size   = 0;
    self->context      = NULL;

    /* assign */
    self->compare = compare;
}

u32_t
SortExRun_refill(SortExRun *self)
{
    ABSTRACT_DEATH(self, "SortExRun_Refill");
    UNREACHABLE_RETURN(u32_t);
}

void
SortExRun_grow_cache(SortExRun *self, u32_t new_cache_cap) 
{
    if (self->cache_cap <= new_cache_cap) {
        /* add 100 elements plus an additional 10% */
        self->cache_cap = new_cache_cap + 100 + (new_cache_cap / 10);
        self->cache = REALLOCATE(self->cache, self->cache_cap, Obj*);
    }
}

Obj*
SortExRun_peek_last(SortExRun *self)
{
    const u32_t tick = self->cache_max - 1;
    if (tick >= self->cache_cap || self->cache_max < 1) {
        CONFESS("Invalid call to Peek_Last: %u %u %u", tick, self->cache_max,
        self->cache_cap);
    }
    return self->cache[tick];
}

u32_t
SortExRun_prepare_slice(SortExRun *self, Obj *endpost) 
{
    i32_t           lo       = self->cache_tick - 1;
    i32_t           hi       = self->cache_max;
    Obj   **const   cache    = self->cache;
    MSort_compare_t compare  = self->compare;
    void   *const   context  = self->context;

    /* binary search */
    while (hi - lo > 1) {
        const i32_t mid   = (lo + hi) / 2;
        const i32_t delta = compare(context, &(cache[mid]), &endpost);
        if (delta > 0) 
            hi = mid;
        else
            lo = mid;
    }

    /* if lo is still -1, we didn't find anything */
    self->slice_size = lo == -1 
        ? 0 
        : (lo - self->cache_tick) + 1;

    return self->slice_size;
}

Obj**
SortExRun_pop_slice(SortExRun *self, u32_t *slice_size)
{
    Obj **retval = self->cache + self->cache_tick;

    /* store slice size via pointer */
    *slice_size      = self->slice_size;

    /* modify internal state */
    self->cache_tick += self->slice_size;
    self->slice_size = 0;
    if (self->cache_tick == self->cache_max) {
        self->cache_max   = 0;
        self->cache_tick  = 0;
    }

    return retval;
}

void
SortExRun_clear_cache(SortExRun *self) 
{
    Obj       **cache   = self->cache + self->cache_tick;
    Obj **const limit   = self->cache + self->cache_max;

    /* only destroy items which haven't been popped */
    for ( ;cache < limit; cache++) {
        REFCOUNT_DEC(*cache);
    }

    self->cache_max   = 0;
    self->cache_tick  = 0;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

