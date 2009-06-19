#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Util/SortExternal.h"
#include "KinoSearch/Util/SortExRun.h"

/* Refill the main cache, drawing from the caches of all runs.
 */
static void
S_refill_cache(SortExternal *self);

/* Refill any runs which are currently empty.  Discard runs which are
 * exhausted.
 */
static void
S_refill_runs(SortExternal *self);

/* Absorb all the items which are "in-range" from all the Runs into the main
 * cache.
 */
static void
S_absorb_slices(SortExternal *self, Obj *endpost);

static void 
S_merge_slices(SortExternal *self, Obj ***slice_starts, u32_t *slice_sizes,
               u32_t num_slices);

/* Return a pointer to the item in one of the runs' caches which is 
 * the highest in sort order, but which we can guarantee is lower in sort
 * order than any item which has yet to enter a run cache. 
 */
static Obj*
S_find_endpost(SortExternal *self);

SortExternal*
SortEx_init(SortExternal *self, u32_t mem_thresh, MSort_compare_t compare)
{
    /* Init. */
    self->cache           = NULL;
    self->cache_cap       = 0;
    self->cache_max       = 0;
    self->cache_tick      = 0;
    self->runs            = NULL;
    self->num_runs        = 0;
    self->scratch         = NULL;
    self->scratch_cap     = 0;
    self->mem_consumed    = 0;
    self->flipped         = false;

    /* Assign. */
    self->compare         = compare;
    self->mem_thresh      = mem_thresh == 0 
        ? SORTEX_DEFAULT_MEM_THRESHOLD 
        : mem_thresh;
    
    ABSTRACT_CLASS_CHECK(self, SORTEXTERNAL);
    return self;
}

void
SortEx_destroy(SortExternal *self) 
{
    if (self->cache) SortEx_Clear_Cache(self);
    free(self->cache);
    free(self->scratch);
    if (self->runs) {
        u32_t i;
        for (i = 0; i < self->num_runs; i++) {
            DECREF(self->runs[i]);
        }
        free(self->runs);
    }
    FREE_OBJ(self);
}

void
SortEx_clear_cache(SortExternal *self) 
{
    Obj **cache  = self->cache + self->cache_tick;
    Obj **limit  = self->cache + self->cache_max;

    /* Only blow away items that haven't been released. */
    for ( ;cache < limit; cache++) {
        DECREF(*cache);
    }

    self->mem_consumed = 0;
    self->cache_max    = 0;
    self->cache_tick   = 0;
}

void
SortEx_feed(SortExternal *self, Obj *obj, u32_t bytes_this_object)
{
    /* Add room for more cache elements if needed. */
    if (self->cache_max == self->cache_cap) {
        /* Add 100, plus 10% of the current capacity. */
        self->cache_cap = self->cache_cap + 100 + (self->cache_cap / 8);
        self->cache = REALLOCATE(self->cache, self->cache_cap, Obj*);
    }

    self->cache[ self->cache_max ] = INCREF(obj);
    self->cache_max++;
        
    /* Check if it's time to flush the cache. */
    self->mem_consumed += bytes_this_object;
    if (self->mem_consumed >= self->mem_thresh) {
        SortEx_Flush(self);
    }
}

Obj*
SortEx_fetch(SortExternal *self) 
{
    if (self->cache_tick >= self->cache_max) {
        if (!self->flipped)
            THROW("Fetch called before Flip");
        S_refill_cache(self);
    }

    if (self->cache_max > 0) {
        return self->cache[ self->cache_tick++ ];
    }
    else {
        return NULL;
    }
}


Obj*
SortEx_peek(SortExternal *self) 
{
    if (self->cache_tick >= self->cache_max) {
        if (!self->flipped)
            THROW("Fetch called before Flip");
        S_refill_cache(self);
    }

    if (self->cache_max > 0) {
        return self->cache[ self->cache_tick ];
    }
    else {
        return NULL;
    }
}

void
SortEx_sort_cache(SortExternal *self) 
{
    if (self->scratch_cap < self->cache_max) {
        self->scratch_cap = self->cache_max;
        self->scratch = REALLOCATE(self->scratch, self->scratch_cap, Obj*);
    }
    MSort_mergesort(self->cache, self->scratch, self->cache_max, sizeof(Obj*),
        self->compare, self);
}

void
SortEx_flip(SortExternal *self)
{
    SortEx_Flush(self);
    self->flipped = true;
}

void
SortEx_add_run(SortExternal *self, SortExRun *run)
{
    self->num_runs++;
    self->runs = REALLOCATE(self->runs, self->num_runs, SortExRun*);
    self->runs[ self->num_runs - 1 ] = (SortExRun*)INCREF(run);
}

static void
S_refill_cache(SortExternal *self) 
{
    Obj   *endpost;

    /* Free all the existing elems, as they've been fetched by now. */
    SortEx_Clear_Cache(self);
    
    /* Bail if we've exhausted every element in every run. */
    S_refill_runs(self);
    if (!self->num_runs)
        return;

    /* Absorb as many elems as possible from all runs into main cache. */
    endpost = S_find_endpost(self);
    S_absorb_slices(self, endpost);
}

static void
S_refill_runs(SortExternal *self)
{
    u32_t i = 0;

    /* Make sure all runs have at least one item in the cache. */
    while (i < self->num_runs) {
        SortExRun *const run = self->runs[i];
        if (SORTEXRUN_CACHE_COUNT(run) > 0 || SortExRun_Refill(run) > 0) {
            /* Run has some elements, so keep. */
            i++;
        }
        else {
            /* Splice out empty runs. */
            DECREF(run);
            self->num_runs--;
            self->runs[i] = self->runs[ self->num_runs ];
            self->runs[ self->num_runs ] = NULL;
        }
    }
}

static Obj*
S_find_endpost(SortExternal *self) 
{
    const MSort_compare_t compare = self->compare;
    Obj        *endpost           = NULL;
    u32_t       i;

    for (i = 0; i < self->num_runs; i++) {
        Obj *candidate;
        /* Get a run and retrieve the last item in its cache. */
        SortExRun *const run = self->runs[i];
        candidate = SortExRun_Peek_Last(run);

        /* If it's the first run, the item is automatically the new endpost. */
        if (i == 0) {
            endpost = candidate;
            continue;
        }
        /* If it's less than the current endpost, it's the new endpost. */
        else if (compare(self, &candidate, &endpost) < 0) {
            endpost = candidate;
        }
    }

    return endpost;
}

static void
S_absorb_slices(SortExternal *self, Obj *endpost)
{
    Obj      ***slice_starts       = MALLOCATE(self->num_runs, Obj**);
    u32_t      *slice_sizes        = MALLOCATE(self->num_runs, u32_t);
    u32_t i = 0, j = 0, num_slices = 0, slice_start = 0, total = 0;

    /* Copy all the elements in range into the cache. */
    for (i = 0; i < self->num_runs; i++) {
        SortExRun *const run = self->runs[i];
        u32_t slice_size;
        Obj **slice = SortExRun_Pop_Slice(run, endpost, &slice_size);

        /* Skip slices that don't have any elements. */
        if (slice_size == 0)
            continue;

        /* Copy slice content into our cache and track location. */
        slice_sizes[j]  = slice_size;
        slice_start += slice_size;
        if (total + slice_size > self->cache_cap) {
            self->cache_cap = total + slice_size;
            self->cache = REALLOCATE(self->cache, self->cache_cap, Obj*);
        }       
        memcpy(self->cache + total, slice, (slice_size * sizeof(Obj*)) );
        total += slice_size;

        /* Track number of slices. */
        num_slices = ++j;
    }
    self->cache_max = total;
    
    /* Transform slice starts from ticks to pointers. */
    total = 0;
    for (i = 0; i < num_slices; i++) {
        slice_starts[i] = self->cache + total;
        total += slice_sizes[i];
    }

    /* Absorb the run slices. */
    if (self->scratch_cap < self->cache_cap) {
        self->scratch_cap = self->cache_cap;
        self->scratch = REALLOCATE(self->scratch, self->scratch_cap, Obj*);
    }
    S_merge_slices(self, slice_starts, slice_sizes, num_slices);

    free(slice_starts);
    free(slice_sizes);
}

static void 
S_merge_slices(SortExternal *self, Obj ***slice_starts, u32_t *slice_sizes,
             u32_t num_slices) 
{
    const MSort_compare_t compare  = self->compare;
    u32_t i = 0, j = 0;

    /* Exploit previous sorting, rather than sort cache naively. */
    while (num_slices > 1) {
        /* Leave the first slice intact if the number of slices is odd. */
        i = 0;
        j = 0;
        while (i < num_slices) {
            if (num_slices - i >= 2) {
                /* Merge two consecutive slices. */
                const u32_t slice_size = slice_sizes[i] + slice_sizes[i+1];

                if (sizeof(Obj*) == 4)
                    MSort_merge4(slice_starts[i], slice_sizes[i],
                        slice_starts[i+1], slice_sizes[i+1], self->scratch,
                        compare, self);
                else 
                    MSort_merge8(slice_starts[i], slice_sizes[i],
                        slice_starts[i+1], slice_sizes[i+1], self->scratch,
                        compare, self);
                slice_sizes[j] = slice_size;
                slice_starts[j] = slice_starts[i];
                memcpy(slice_starts[j], self->scratch, 
                    (slice_size * sizeof(Obj*)) );

                i += 2;
                j += 1;
            }
            else if (num_slices - i >= 1) {
                /* Move single slice pointer. */
                slice_sizes[j]  = slice_sizes[i];
                slice_starts[j] = slice_starts[i];
                i += 1;
                j += 1;
            }
        }
        num_slices = j;
    }
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

