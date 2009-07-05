#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Util/SortExRun.h"

/* Determine how many items in the cache are less than or equal to [endpost]. */
static u32_t
S_find_slice_size(SortExRun *self, Obj *endpost);

SortExRun*
SortExRun_init(SortExRun *self)
{
    /* Init. */
    self->cache        = NULL;
    self->cache_cap    = 0;
    self->cache_max    = 0;
    self->cache_tick   = 0;

    ABSTRACT_CLASS_CHECK(self, SORTEXRUN);
    return self;
}

void
SortExRun_destroy(SortExRun *self)
{
    if (self->cache) {
        SortExRun_Clear_Cache(self);
        FREEMEM(self->cache);
    }
    FREE_OBJ(self);
}

u32_t
SortExRun_refill(SortExRun *self)
{
    /* Make sure cache is empty, then set cache tick vars. */
    if (self->cache_max - self->cache_tick > 0) {
        THROW("Refill called but cache contains %u32 items",
            self->cache_max - self->cache_tick);
    }
    self->cache_tick = 0;
    self->cache_max  = 0;

    /* Read in elements. */
    while (1) {
        Obj *elem = SortExRun_Read_Elem(self);
        if (elem == NULL) break;
        if (self->cache_max == self->cache_cap) {
            SortExRun_Grow_Cache(self, self->cache_max);
        }
        self->cache[ self->cache_max++ ] = elem;
    }

    return self->cache_max;
}

void
SortExRun_grow_cache(SortExRun *self, u32_t new_cache_cap) 
{
    if (self->cache_cap <= new_cache_cap) {
        /* Add 100 elements plus an additional 10%. */
        self->cache_cap = new_cache_cap + 100 + (new_cache_cap / 10);
        self->cache = REALLOCATE(self->cache, self->cache_cap, Obj*);
    }
}

Obj*
SortExRun_peek_last(SortExRun *self)
{
    const u32_t tick = self->cache_max - 1;
    if (tick >= self->cache_cap || self->cache_max < 1) {
        THROW("Invalid call to Peek_Last: %u32 %u32 %u32", tick, self->cache_max,
        self->cache_cap);
    }
    return self->cache[tick];
}

static u32_t
S_find_slice_size(SortExRun *self, Obj *endpost) 
{
    i32_t           lo       = self->cache_tick - 1;
    i32_t           hi       = self->cache_max;
    Obj   **const   cache    = self->cache;

    /* Binary search. */
    while (hi - lo > 1) {
        const i32_t mid   = lo + ((hi - lo) / 2);
        const i32_t delta = SortExRun_Compare(self, &(cache[mid]), &endpost);
        if (delta > 0) 
            hi = mid;
        else
            lo = mid;
    }

    /* If lo is still -1, we didn't find anything. */
    return lo == -1 
        ? 0 
        : (lo - self->cache_tick) + 1;
}

Obj**
SortExRun_pop_slice(SortExRun *self, Obj *endpost, u32_t *slice_size)
{
    Obj **retval = self->cache + self->cache_tick;

    /* Store slice size via pointer. */
    *slice_size = S_find_slice_size(self, endpost);

    /* Modify internal state. */
    self->cache_tick += *slice_size;
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

    /* Only destroy items which haven't been popped. */
    for ( ;cache < limit; cache++) {
        DECREF(*cache);
    }

    self->cache_max   = 0;
    self->cache_tick  = 0;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

