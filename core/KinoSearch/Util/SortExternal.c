#define C_KINO_SORTEXTERNAL
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Util/SortExternal.h"

/* Refill the main cache, drawing from the caches of all runs.
 */
static void
S_refill_cache(SortExternal *self);

/* Absorb all the items which are "in-range" from all the Runs into the main
 * cache.
 */
static void
S_absorb_slices(SortExternal *self, Obj *endpost);

/* Return a pointer to the item in one of the runs' caches which is 
 * the highest in sort order, but which we can guarantee is lower in sort
 * order than any item which has yet to enter a run cache. 
 */
static Obj*
S_find_endpost(SortExternal *self);

/* Determine how many cache items are less than or equal to [endpost]. */
static u32_t
S_find_slice_size(SortExternal *self, Obj *endpost);

SortExternal*
SortEx_init(SortExternal *self, u32_t mem_thresh)
{
    /* Assign. */
    self->mem_thresh      = mem_thresh;

    /* Init. */
    self->cache        = NULL;
    self->cache_cap    = 0;
    self->cache_max    = 0;
    self->cache_tick   = 0;
    self->scratch      = NULL;
    self->scratch_cap  = 0;
    self->runs         = VA_new(0);
    self->slice_sizes  = NULL;
    self->slice_starts = NULL;
    self->num_slices   = 0;
    self->mem_consumed = 0;
    self->flipped      = false;
    
    ABSTRACT_CLASS_CHECK(self, SORTEXTERNAL);
    return self;
}

void
SortEx_destroy(SortExternal *self) 
{
    FREEMEM(self->scratch);
    FREEMEM(self->slice_sizes);
    FREEMEM(self->slice_starts);
    if (self->cache) {
        SortEx_Clear_Cache(self);
        FREEMEM(self->cache);
    }
    DECREF(self->runs);
    SUPER_DESTROY(self, SORTEXTERNAL);
}

void
SortEx_clear_cache(SortExternal *self) 
{
    Obj **const cache = self->cache;
    for ( uint32_t i = self->cache_tick, max = self->cache_max; i < max; i++) {
        DECREF(cache[i]);
    }
    self->cache_max   = 0;
    self->cache_tick  = 0;
    self->mem_consumed = 0;
}

void
SortEx_feed(SortExternal *self, Obj *item)
{
    if (self->cache_max == self->cache_cap) {
        size_t amount = Memory_oversize(self->cache_max + 1, sizeof(Obj*));
        SortEx_Grow_Cache(self, amount);
    }
    self->cache[ self->cache_max++ ] = item;
}

static INLINE Obj*
SI_peek(SortExternal *self)
{
    if (self->cache_tick >= self->cache_max) {
        if (!self->flipped) { THROW(ERR, "Flip not called yet"); }
        S_refill_cache(self);
    }

    if (self->cache_max > 0) {
        return self->cache[ self->cache_tick ];
    }
    else {
        return NULL;
    }
}

Obj*
SortEx_fetch(SortExternal *self) 
{
    Obj *item = SI_peek(self);
    self->cache_tick++;
    return item;
}

Obj*
SortEx_peek(SortExternal *self) 
{
    return SI_peek(self);
}

void
SortEx_sort_cache(SortExternal *self) 
{
    if (self->cache_tick != 0) {
        THROW(ERR, "Cant Sort_Cache() after fetching %u32 items", self->cache_tick);
    }
    if (self->cache_max != 0) {
        VTable *vtable = SortEx_Get_VTable(self);
        Sort_compare_t compare 
            = (Sort_compare_t)METHOD(vtable, SortEx, Compare);
        if (self->scratch_cap < self->cache_cap) {
            self->scratch_cap = self->cache_cap;
            self->scratch = (Obj**)REALLOCATE(self->scratch, self->scratch_cap * sizeof(Obj*));
        }
        Sort_mergesort(self->cache, self->scratch, self->cache_max,
            sizeof(Obj*), compare, self);
    }
}

void
SortEx_flip(SortExternal *self)
{
    SortEx_Flush(self);
    self->flipped = true;
}

void
SortEx_add_run(SortExternal *self, SortExternal *run)
{
    VA_Push(self->runs, (Obj*)run);
    uint32_t num_runs = VA_Get_Size(self->runs);
    self->slice_sizes = (u32_t*)REALLOCATE(self->slice_sizes, 
        num_runs * sizeof(u32_t));
    self->slice_starts = (Obj***)REALLOCATE(self->slice_starts,
        num_runs * sizeof(Obj**));
}

static void
S_refill_cache(SortExternal *self) 
{
    /* Reset cache vars. */
    SortEx_Clear_Cache(self);
    
    /* Make sure all runs have at least one item in the cache. */
    uint32_t i = 0;
    while (i < VA_Get_Size(self->runs)) {
        SortExternal *const run = (SortExternal*)VA_Fetch(self->runs, i);
        if (SortEx_Cache_Count(run) > 0 || SortEx_Refill(run) > 0) {
            i++; /* Run has some elements, so keep. */
        }
        else {
            VA_Splice(self->runs, i, 1);
        }
    }

    /* Absorb as many elems as possible from all runs into main cache. */
    if (VA_Get_Size(self->runs)) {
        Obj *endpost = S_find_endpost(self);
        S_absorb_slices(self, endpost);
    }
}

static Obj*
S_find_endpost(SortExternal *self) 
{
    Obj *endpost = NULL;

    for ( uint32_t i = 0, max = VA_Get_Size(self->runs); i < max; i++) {
        /* Get a run and retrieve the last item in its cache. */
        SortExternal *const run = (SortExternal*)VA_Fetch(self->runs, i);
        const u32_t tick = run->cache_max - 1;
        if (tick >= run->cache_cap || run->cache_max < 1) {
            THROW(ERR, "Invalid SortExternal cache access: %u32 %u32 %u32", tick, 
                run->cache_max, run->cache_cap);
        }
        else {
            /* Cache item with the highest sort value currently held in memory
             * by the run.
             */
            Obj *candidate = run->cache[tick];

            /* If it's the first run, item is automatically the new endpost. */
            if (i == 0) {
                endpost = candidate;
            }
            /* If it's less than the current endpost, it's the new endpost. */
            else if (SortEx_Compare(self, &candidate, &endpost) < 0) {
                endpost = candidate;
            }
        }
    }

    return endpost;
}

static void
S_absorb_slices(SortExternal *self, Obj *endpost)
{
    uint32_t    num_runs     = VA_Get_Size(self->runs);
    Obj      ***slice_starts = self->slice_starts;
    uint32_t   *slice_sizes  = self->slice_sizes;
    VTable     *vtable       = SortEx_Get_VTable(self);
    Sort_compare_t compare   = (Sort_compare_t)METHOD(vtable, SortEx, Compare);

    if (self->cache_max != 0) { THROW(ERR, "Can't refill unless empty"); }

    /* Move all the elements in range into the main cache as slices. */
    for (uint32_t i = 0; i < num_runs; i++) {
        SortExternal *const run = (SortExternal*)VA_Fetch(self->runs, i);
        uint32_t slice_size = S_find_slice_size(run, endpost);

        if (slice_size) {
            /* Move slice content from run cache to main cache. */
            if (self->cache_max + slice_size > self->cache_cap) {
                size_t cap = Memory_oversize(self->cache_max + slice_size, 
                    sizeof(Obj*));
                SortEx_Grow_Cache(self, cap);
            }
            memcpy(self->cache + self->cache_max, 
                run->cache + run->cache_tick,
                (slice_size * sizeof(Obj*)) );
            run->cache_tick += slice_size;
            self->cache_max += slice_size;

            /* Track number of slices and slice sizes. */
            slice_sizes[self->num_slices++] = slice_size;
        }
    }
    
    /* Transform slice starts from ticks to pointers. */
    uint32_t total = 0;
    for (uint32_t i = 0; i < self->num_slices; i++) {
        slice_starts[i] = self->cache + total;
        total += slice_sizes[i];
    }

    /* The main cache now consists of several slices.  Sort the main cache,
     * but exploit the fact that each slice is already sorted. */
    if (self->scratch_cap < self->cache_cap) {
        self->scratch_cap = self->cache_cap;
        self->scratch = (Obj**)REALLOCATE(self->scratch, self->scratch_cap * sizeof(Obj*));
    }

    /* Exploit previous sorting, rather than sort cache naively.
     * Leave the first slice intact if the number of slices is odd. */
    while (self->num_slices > 1) {
        uint32_t i = 0;
        uint32_t j = 0;

        while (i < self->num_slices) {
            if (self->num_slices - i >= 2) {
                /* Merge two consecutive slices. */
                const uint32_t merged_size = slice_sizes[i] + slice_sizes[i+1];
                Sort_merge(slice_starts[i], slice_sizes[i],
                    slice_starts[i+1], slice_sizes[i+1], self->scratch,
                    sizeof(void*), compare, self);
                slice_sizes[j]  = merged_size;
                slice_starts[j] = slice_starts[i];
                memcpy(slice_starts[j], self->scratch, 
                    (merged_size * sizeof(Obj*)) );
                i += 2;
                j += 1;
            }
            else if (self->num_slices - i >= 1) {
                /* Move single slice pointer. */
                slice_sizes[j]  = slice_sizes[i];
                slice_starts[j] = slice_starts[i];
                i += 1;
                j += 1;
            }
        }
        self->num_slices = j;
    }

    self->num_slices = 0;
}

u32_t
SortEx_refill(SortExternal *self)
{
    /* Make sure cache is empty, then set cache tick vars. */
    if (self->cache_max - self->cache_tick > 0) {
        THROW(ERR, "Refill called but cache contains %u32 items",
            self->cache_max - self->cache_tick);
    }
    self->cache_tick = 0;
    self->cache_max  = 0;

    /* Read in elements. */
    while (1) {
        Obj *elem = SortEx_Recover_Item(self);
        if (elem == NULL) break;
        if (self->cache_max == self->cache_cap) {
            SortEx_Grow_Cache(self,
                Memory_oversize(self->cache_max + 1, sizeof(Obj*)));
        }
        self->cache[ self->cache_max++ ] = elem;
    }

    return self->cache_max;
}

void
SortEx_grow_cache(SortExternal *self, u32_t size) 
{
    if (size > self->cache_cap) {
        self->cache = (Obj**)REALLOCATE(self->cache, size * sizeof(Obj*));
        self->cache_cap = size;
    }
}

static u32_t
S_find_slice_size(SortExternal *self, Obj *endpost) 
{
    i32_t           lo       = self->cache_tick - 1;
    i32_t           hi       = self->cache_max;
    Obj   **const   cache    = self->cache;

    /* Binary search. */
    while (hi - lo > 1) {
        const i32_t mid   = lo + ((hi - lo) / 2);
        const i32_t delta = SortEx_Compare(self, &(cache[mid]), &endpost);
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

void
SortEx_set_mem_thresh(SortExternal *self, u32_t mem_thresh)
{
    self->mem_thresh = mem_thresh;
}

u32_t
SortEx_cache_count(SortExternal *self)
{
    return self->cache_max - self->cache_tick;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

