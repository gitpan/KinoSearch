#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SORTEXTERNAL_VTABLE
#include "KinoSearch/Util/SortExternal.r"

#include "KinoSearch/Util/SortExRun.r"

/* Allocate more memory to an array of pointers to pointers to Objs, if
 * the current allocation isn't sufficient.
 */
static void
grow_obj_buf(Obj ***bb_buf, u32_t current, u32_t desired);

/* Refill the main cache, drawing from the caches of all runs.
 */
static void
refill_cache(SortExternal *self);

/* Refill any runs which are currently empty.  Discard runs which are
 * exhausted.
 */
static void
refill_runs(SortExternal *self);

/* Merge all the items which are "in-range" from all the Runs into the main
 * cache.
 */
static void 
merge_slices(SortExternal *self);

/* Return a pointer to the item in one of the runs' caches which is 
 * the highest in sort order, but which we can guarantee is lower in sort
 * order than any item which has yet to enter a run cache. 
 */
static Obj*
find_endpost(SortExternal *self);

void
SortEx_init_base(SortExternal *self, u32_t mem_thresh, 
                 MSort_compare_t compare)
{
    /* init */
    self->cache           = NULL;
    self->cache_cap       = 0;
    self->cache_max       = 0;
    self->cache_tick      = 0;
    self->runs            = NULL;
    self->num_runs        = 0;
    self->scratch         = NULL;
    self->scratch_cap     = 0;
    self->consumed        = 0;
    self->flipped         = false;
    self->context         = NULL;

    /* assign */
    self->compare         = compare;
    self->mem_thresh      = mem_thresh == 0 
        ? KINO_SORTEX_DEFAULT_MEM_THRESHOLD 
        : mem_thresh;
}


void
SortEx_destroy(SortExternal *self) 
{
    u32_t i;
    
    /* free the cache and the scratch */
    SortEx_Clear_Cache(self);
    free(self->cache);
    free(self->scratch);

    /* free all of the runs and the array that held them */
    for (i = 0; i < self->num_runs; i++) {
        REFCOUNT_DEC(self->runs[i]);
    }
    free(self->runs);

    /* free context */
    REFCOUNT_DEC(self->context);

    /* free me */
    free(self);
}

void
SortEx_clear_cache(SortExternal *self) 
{
    Obj **cache  = self->cache + self->cache_tick;
    Obj **limit  = self->cache + self->cache_max;

    /* only blow away items that haven't been released */
    for ( ;cache < limit; cache++) {
        REFCOUNT_DEC(*cache);
    }

    self->consumed    = 0;
    self->cache_max   = 0;
    self->cache_tick  = 0;
}

static void
grow_obj_buf(Obj ***bb_buf, u32_t current, u32_t desired) 
{
    if (current < desired)
        *bb_buf = REALLOCATE(*bb_buf, desired, Obj*); 
}

void
SortEx_feed(SortExternal *self, Obj *obj, u32_t bytes_this_object)
{
    REFCOUNT_INC(obj);

    /* add room for more cache elements if needed */
    if (self->cache_max == self->cache_cap) {
        /* add 100, plus 10% of the current capacity */
        self->cache_cap = self->cache_cap + 100 + (self->cache_cap / 8);
        self->cache = REALLOCATE(self->cache, self->cache_cap, Obj*);
    }

    self->cache[ self->cache_max ] = obj;
    self->cache_max++;
        
    /* track memory consumed */
    self->consumed += bytes_this_object;

    /* check if it's time to flush the cache */
    if (self->consumed >= self->mem_thresh) {
        SortEx_Flush(self);
    }
}

Obj*
SortEx_fetch(SortExternal *self) 
{
    if (self->cache_tick >= self->cache_max) {
        if (!self->flipped)
            CONFESS("Fetch called before Flip");
        refill_cache(self);
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
            CONFESS("Fetch called before Flip");
        refill_cache(self);
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
    grow_obj_buf(&self->scratch, self->scratch_cap, self->cache_max);
    MSort_mergesort(self->cache, self->scratch, self->cache_max, sizeof(Obj*),
        self->compare, self->context);
}

void
SortEx_flush(SortExternal *self)
{
    ABSTRACT_DEATH(self, "SortEx_Flush");
}

void
SortEx_flip(SortExternal *self)
{
    ABSTRACT_DEATH(self, "SortEx_Flip");
}

void
SortEx_add_run(SortExternal *self, SortExRun *run)
{
    self->num_runs++;
    self->runs = REALLOCATE(self->runs, self->num_runs, SortExRun*);
    self->runs[ self->num_runs - 1 ] = run;
    REFCOUNT_INC(run);
}

static void
refill_cache(SortExternal *self) 
{
    Obj   *endpost;
    u32_t  i;
    u32_t  total = 0;

    /* free all the existing ByteBufs, as they've been fetched by now */
    SortEx_Clear_Cache(self);
    
    /* bail if we've exhausted every element in every run */
    refill_runs(self);
    if (!self->num_runs)
        return;

    /* find all items in all runs which can be transferred to the cache */
    endpost = find_endpost(self);
    for (i = 0; i < self->num_runs; i++) {
        total += SortExRun_Prepare_Slice(self->runs[i], endpost);
    }

    /* make sure we have enough room in both the main cache and the scratch */
    grow_obj_buf(&self->cache,   self->cache_cap,   total);
    grow_obj_buf(&self->scratch, self->scratch_cap, total);

    /* absorb the run slices */
    merge_slices(self);
    self->cache_max = total;
}

static Obj*
find_endpost(SortExternal *self) 
{
    const MSort_compare_t compare = self->compare;
    void *const context           = self->context;
    Obj        *endpost           = NULL;
    u32_t       i;

    for (i = 0; i < self->num_runs; i++) {
        Obj *candidate;
        /* get a run and retrieve the last item in its cache */
        SortExRun *const run = self->runs[i];
        candidate = SortExRun_Peek_Last(run);

        /* if it's the first run, the item is automatically the new endpost */
        if (i == 0) {
            endpost = candidate;
            continue;
        }
        /* if it's less than the current endpost, it's the new endpost */
        else if (compare(context, &candidate, &endpost) < 0) {
            endpost = candidate;
        }
    }

    return endpost;
}

static void
refill_runs(SortExternal *self)
{
    u32_t i = 0;

    /* make sure all runs have at least one item in the cache */
    while (i < self->num_runs) {
        SortExRun *const run = self->runs[i];
        if (SORTEXRUN_CACHE_COUNT(run) > 0 || SortExRun_Refill(run) > 0) {
            /* run has some elements, so keep */
            i++;
        }
        else {
            /* splice out empty runs */
            REFCOUNT_DEC(run);
            self->num_runs--;
            self->runs[i] = self->runs[ self->num_runs ];
            self->runs[ self->num_runs ] = NULL;
        }
    }
}

static void 
merge_slices(SortExternal *self) 
{
    const MSort_compare_t compare  = self->compare;
    void *const context            = self->context;
    Obj       **cache              = self->cache;
    Obj      ***slice_starts       = MALLOCATE(self->num_runs, Obj**);
    u32_t      *slice_sizes        = MALLOCATE(self->num_runs, u32_t);
    u32_t i = 0, j = 0, num_slices = 0;

    /* copy all the elements in range into the cache */
    for (i = 0; i < self->num_runs; i++) {
        SortExRun *const run = self->runs[i];
        u32_t slice_size;
        Obj **slice = SortExRun_Pop_Slice(run, &slice_size);

        /* skip slices that don't have any elements */
        if (slice_size == 0)
            continue;

        /* copy slice content into our cache and track location */
        slice_sizes[j]  = slice_size;
        slice_starts[j] = cache;
        memcpy(cache, slice, (slice_size * sizeof(Obj*)) );
        
        /* advance pointer to interior of cache */
        cache += slice_size;

        /* track number of slices */
        num_slices = ++j;
    }

    /* exploit previous sorting, rather than sort cache naively */
    while (num_slices > 1) {
        /* leave the first slice intact if the number of slices is odd */
        i = 0;
        j = 0;
        while (i < num_slices) {
            if (num_slices - i >= 2) {
                /* merge two consecutive slices */
                const u32_t slice_size = slice_sizes[i] + slice_sizes[i+1];

                if (sizeof(Obj*) == 4)
                    MSort_merge4(slice_starts[i], slice_sizes[i],
                        slice_starts[i+1], slice_sizes[i+1], self->scratch,
                        compare, context);
                else 
                    MSort_merge8(slice_starts[i], slice_sizes[i],
                        slice_starts[i+1], slice_sizes[i+1], self->scratch,
                        compare, context);
                slice_sizes[j] = slice_size;
                slice_starts[j] = slice_starts[i];
                memcpy(slice_starts[j], self->scratch, 
                    (slice_size * sizeof(Obj*)) );

                i += 2;
                j += 1;
            }
            else if (num_slices - i >= 1) {
                /* move single slice pointer */
                slice_sizes[j]  = slice_sizes[i];
                slice_starts[j] = slice_starts[i];
                i += 1;
                j += 1;
            }
        }
        num_slices = j;
    }

    free(slice_starts);
    free(slice_sizes);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

