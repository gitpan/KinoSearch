#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SORTEXTERNAL_VTABLE
#include "KinoSearch/Util/SortExternal.r"

#include "KinoSearch/InvIndex.r"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/OutStream.r"

#define SortExRun kino_SortExRun
struct SortExRun {
    u64_t  start;
    u64_t  file_pos;
    u64_t  end;
    struct ByteBuf **cache;
    u32_t   cache_cap;
    u32_t   cache_elems;
    u32_t   cache_pos;
    u32_t   slice_size;
};

/* Create a new SortExRun object.
 */
static SortExRun*
new_run(u64_t start, u64_t end);

/* Destructor for a SortexRun.
 */
static void
destroy_run(SortExRun *run);
    
/* Allocate more memory to an array of pointers to pointers to ByteBufs, if
 * the current allocation isn't sufficient.
 */
static void
grow_bufbuf(ByteBuf ***bb_buf, u32_t current, u32_t desired);

/* Recover sorted items from disk, up to the allowable memory limit. 
 */
static u32_t 
refill_run(SortExternal* self, SortExRun *run);

/* Refill the main cache, drawing from the caches of all runs.
 */
static void
refill_cache(SortExternal *self);

/* Merge all the items which are "in-range" from all the Runs into the main
 * cache.
 */
static void 
merge_runs(SortExternal *self);

/* Return a pointer to the item in one of the runs' caches which is 
 * the highest in sort order, but which we can guarantee is lower in sort
 * order than any item which has yet to enter a run cache. 
 */
static ByteBuf*
find_endpost(SortExternal *self);

/* Record the number of items in the run's cache which are lexically
 * less than or equal to the endpost.
 */
static u32_t
define_slice(SortExRun *run, ByteBuf *endpost);

/* Empty the main cache.
 */
static void
clear_cache(SortExternal *self);

/* Empty the cache belonging to a SortExRun.
 */
static void
clear_run_cache(SortExRun *run);

#define PER_ITEM_OVERHEAD (sizeof(ByteBuf) + sizeof(ByteBuf*))

SortExternal*
SortEx_new(InvIndex *invindex, SegInfo *seg_info, u32_t mem_threshold)
{

    ByteBuf *sortfile_name;
    CREATE(self, SortExternal, SORTEXTERNAL);

    /* init */
    self->cache           = MALLOCATE(100, ByteBuf*);
    self->cache_cap       = 100;
    self->cache_elems     = 0;
    self->cache_pos       = 0;
    self->runs            = MALLOCATE(1, SortExRun*);
    self->num_runs        = 0;
    self->scratch         = NULL;
    self->scratch_cap     = 0;
    self->cache_bytes     = 0;
    self->instream        = NULL;

    /* assign */
    REFCOUNT_INC(invindex);
    REFCOUNT_INC(seg_info);
    self->invindex      = invindex;
    self->seg_info      = seg_info;
    self->mem_threshold = mem_threshold == 0 
        ? KINO_SORTEX_DEFAULT_MEM_THRESHOLD 
        : mem_threshold;
    
    /* create outstream */
    sortfile_name = BB_CLONE(seg_info->seg_name);
    BB_Cat_Str(sortfile_name, ".srt", 4);
    self->outstream = Folder_Open_OutStream(invindex->folder, sortfile_name); 
    REFCOUNT_DEC(sortfile_name);

    /* derive */
    self->run_cache_limit = mem_threshold / 2;

    return self;
}


static SortExRun*
new_run(u64_t start, u64_t end) 
{
    SortExRun *run = MALLOCATE(1, SortExRun);
    
    /* init */
    run->cache        = MALLOCATE(100, ByteBuf*);
    run->cache_cap    = 100;
    run->cache_elems  = 0;
    run->cache_pos    = 0;
    run->slice_size   = 0;

    /* assign */
    run->start    = start;
    run->file_pos = start;
    run->end      = end;

    return run;
}

void
SortEx_destroy(SortExternal *self) 
{
    u32_t i;
    
    /* free individual members */
    REFCOUNT_DEC(self->invindex);
    REFCOUNT_DEC(self->outstream);
    REFCOUNT_DEC(self->instream);
    REFCOUNT_DEC(self->seg_info);

    /* free the cache and the scratch */
    clear_cache(self);
    free(self->cache);
    free(self->scratch);

    /* free all of the runs and the array that held them */
    for (i = 0; i < self->num_runs; i++) {
        destroy_run(self->runs[i]);
    }
    free(self->runs);

    /* free me */
    free(self);
}

static void
destroy_run(SortExRun *run) 
{
    clear_run_cache(run);
    free(run->cache);
    free(run);
}

void
SortEx_feed(SortExternal* self, char* ptr, u32_t len) 
{
    ByteBuf *const bb = BB_new_str(ptr, len);
    SortEx_feed_bb(self, bb);
    REFCOUNT_DEC(bb);
}

void
SortEx_feed_bb(SortExternal *self, ByteBuf *bb)
{
    REFCOUNT_INC(bb);

    /* add room for more cache elements if needed */
    if (self->cache_elems == self->cache_cap) {
        /* add 100, plus 10% of the current capacity */
        self->cache_cap = self->cache_cap + 100 + (self->cache_cap / 8);
        self->cache = REALLOCATE(self->cache, self->cache_cap, ByteBuf*);
    }

    self->cache[ self->cache_elems ] = bb;
    self->cache_elems++;
        
    /* track memory consumed */
    self->cache_bytes += PER_ITEM_OVERHEAD;
    self->cache_bytes += bb->len + 1;

    /* check if it's time to flush the cache */
    if (self->cache_bytes >= self->mem_threshold)
        SortEx_Sort_Run(self);
}

ByteBuf*
SortEx_fetch(SortExternal *self) 
{
    if (self->cache_pos >= self->cache_elems)
        refill_cache(self);

    if (self->cache_elems > 0) {
        return self->cache[ self->cache_pos++ ];
    }
    else {
        return NULL;
    }
}

static void
grow_bufbuf(ByteBuf ***bb_buf, u32_t current, u32_t desired) 
{
    if (current < desired)
        *bb_buf = REALLOCATE(*bb_buf, desired, ByteBuf*); 
}

void
SortEx_sort_cache(SortExternal *self) 
{
    grow_bufbuf(&self->scratch, self->scratch_cap, self->cache_elems);
    MSort_mergesort(self->cache, self->scratch, 
        self->cache_elems);
}

void
SortEx_sort_run(SortExternal *self) 
{
    OutStream  *outstream = self->outstream;
    ByteBuf   **cache     = self->cache;
    ByteBuf   **cache_end = cache + self->cache_elems;
    u64_t       start, end;

    /* bail if there's nothing in the cache */
    if (self->cache_bytes == 0)
        return;

    /* allocate space for a new run */
    self->num_runs++;
    self->runs = REALLOCATE(self->runs, self->num_runs, SortExRun*);

    /* mark start of run */
    start = OutStream_STell(outstream);
    
    /* write sorted items to file */
    SortEx_Sort_Cache(self);
    for (cache = self->cache; cache < cache_end; cache++) {
        ByteBuf *const bb = *cache;
        OutStream_Write_VInt(outstream, bb->len);
        OutStream_Write_Bytes(outstream, bb->ptr, bb->len);
    }

    /* clear the cache */
    clear_cache(self);

    /* mark end of run and build a new SortExRun object */
    end = OutStream_STell(outstream);
    self->runs[ self->num_runs - 1 ] = new_run(start, end);

    /* recalculate the size allowed for each run's cache */
    self->run_cache_limit = (self->mem_threshold / 2) / self->num_runs;
    self->run_cache_limit = self->run_cache_limit < 65536
        ? 65536 
        : self->run_cache_limit;
}

static u32_t 
refill_run(SortExternal* self, SortExRun *run) 
{
    InStream *instream        = self->instream;
    u32_t     run_cache_limit = self->run_cache_limit;
    u64_t     end             = run->end;
    u32_t     run_cache_bytes = 0;
    u32_t     num_elems       = 0; /* number of items recovered */
    u32_t     len;
    ByteBuf  *bb;

    /* see if we actually need to refill */
    if (run->cache_elems - run->cache_pos)
        return run->cache_elems - run->cache_pos;
    else 
        clear_run_cache(run);

    InStream_SSeek(instream, run->file_pos);

    while (1) {
        /* bail if we've read everything in this run */
        if (InStream_STell(instream) >= end) {
            /* make sure we haven't read too much */
            if (InStream_STell(instream) > end) {
                unsigned long pos = (unsigned long)InStream_STell(instream);
                CONFESS("read past end of run: %lu %lu", pos, 
                    (unsigned long)end);
            }
            break;
        }

        /* bail if we've hit the ceiling for this run's cache */
        if (run_cache_bytes > run_cache_limit)
            break;

        /* retrieve and decode len; allocate a ByteBuf and recover the string */
        len = InStream_Read_VInt(instream);
        bb  = BB_new(len);
        InStream_Read_Bytes(instream, bb->ptr, len);
        bb->len = len;
        *BBEND(bb) = '\0';

        /* add to the run's cache */
        if (num_elems == run->cache_cap) {
            run->cache_cap = run->cache_cap + 100 + (run->cache_cap / 8);
            run->cache = REALLOCATE(run->cache, (u32_t)run->cache_cap, ByteBuf*);
        }
        run->cache[ num_elems ] = bb;

        /* track how much we've read so far */
        num_elems++;
        run_cache_bytes += len + 1 + PER_ITEM_OVERHEAD;
    }

    /* reset the cache array position and length; remember file pos */
    run->cache_elems = num_elems;
    run->cache_pos   = 0;
    run->file_pos    = InStream_STell(instream);

    return num_elems;
}

static void
refill_cache(SortExternal *self) 
{
    ByteBuf   *endpost;
    u32_t i = 0;
    u32_t total = 0;

    /* free all the existing ByteBufs, as they've been fetched by now */
    clear_cache(self);
    
    /* make sure all runs have at least one item in the cache */
    while (i < self->num_runs) {
        SortExRun *const run = self->runs[i];
        if (   (run->cache_elems > run->cache_pos)
            || (refill_run(self, run)) 
        ) {
            i++;
        }
        else {
            /* discard empty runs */
            destroy_run(run);
            self->num_runs--;
            self->runs[i] = self->runs[ self->num_runs ];
            self->runs[ self->num_runs ] = NULL;
        }
    }

    if (!self->num_runs)
        return;

    /* move as many items as possible into the sorting cache */
    endpost = find_endpost(self);
    for (i = 0; i < self->num_runs; i++) {
        total += define_slice(self->runs[i], endpost);
    }

    /* make sure we have enough room in both the main cache and the scratch */
    grow_bufbuf(&self->cache,   self->cache_cap,   total);
    grow_bufbuf(&self->scratch, self->scratch_cap, total);

    merge_runs(self);
    self->cache_elems = total;
}

static void 
merge_runs(SortExternal *self) 
{
    ByteBuf  **cache        = self->cache;
    ByteBuf ***slice_starts = MALLOCATE(self->num_runs, ByteBuf**);
    u32_t     *slice_sizes  = MALLOCATE( self->num_runs, u32_t);
    u32_t      i = 0, j = 0, num_slices = 0;


    /* copy all the elements in range into the cache */
    for (i = 0; i < self->num_runs; i++) {
        SortExRun *const run = self->runs[i];
        const u32_t slice_size  = run->slice_size;
        if (slice_size == 0)
            continue;

        slice_sizes[j]  = slice_size;
        slice_starts[j] = cache;
        memcpy(cache, (run->cache + run->cache_pos), 
            (slice_size * sizeof(ByteBuf*)) );
        
        run->cache_pos += slice_size;
        cache += slice_size;
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

                MSort_merge(slice_starts[i], slice_sizes[i],
                    slice_starts[i+1], slice_sizes[i+1], self->scratch);
                slice_sizes[j] = slice_size;
                slice_starts[j] = slice_starts[i];
                memcpy(slice_starts[j], self->scratch, 
                    (slice_size * sizeof(ByteBuf*)) );

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

static ByteBuf*
find_endpost(SortExternal *self) 
{
    u32_t  i;
    ByteBuf    *endpost = NULL;

    for (i = 0; i < self->num_runs; i++) {
        ByteBuf *candidate;
        /* get a run and verify no errors */
        SortExRun *const run = self->runs[i];
        if (run->cache_pos == run->cache_elems || run->cache_elems < 1)
            CONFESS("find_endpost encountered an empty run cache");

        /* get the last item in this run's cache */
        candidate = run->cache[ run->cache_elems - 1 ];

        /* if it's the first run, the item is automatically the new endpost */
        if (i == 0) {
            endpost = candidate;
            continue;
        }
        /* if it's less than the current endpost, it's the new endpost */
        else if (BB_compare(&candidate, &endpost) < 0) {
            endpost = candidate;
        }
    }

    return endpost;
}

static u32_t
define_slice(SortExRun *run, ByteBuf *endpost) 
{
    /* operate on a slice of the cache */
    i32_t lo   = run->cache_pos - 1;
    i32_t hi   = run->cache_elems;
    ByteBuf **cache = run->cache;

    /* binary search */
    while (hi - lo > 1) {
        const i32_t mid   = (lo + hi) / 2;
        const i32_t delta = BB_compare(&(cache[mid]), &endpost);
        if (delta > 0) 
            hi = mid;
        else
            lo = mid;
    }

    run->slice_size = lo == -1 
        ? 0 
        : (lo - run->cache_pos) + 1;
    return run->slice_size;
}

static void
clear_cache(SortExternal *self) 
{
    ByteBuf **cache     = self->cache + self->cache_pos;
    ByteBuf **cache_end = self->cache + self->cache_elems;

    /* only blow away items that haven't been released */
    for ( ;cache < cache_end; cache++) {
        REFCOUNT_DEC(*cache);
    }

    self->cache_bytes = 0;
    self->cache_elems = 0;
    self->cache_pos   = 0;
}

static void
clear_run_cache(SortExRun *run) 
{
    ByteBuf **cache     = run->cache + run->cache_pos;
    ByteBuf **cache_end = run->cache + run->cache_elems;

    /* only destroy items which haven't been passed to the main cache */
    for ( ;cache < cache_end; cache++) {
        REFCOUNT_DEC(*cache);
    }

    run->cache_elems = 0;
    run->cache_pos   = 0;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

