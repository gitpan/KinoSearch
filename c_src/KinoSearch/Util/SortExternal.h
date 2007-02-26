#ifndef H_KINO_SORTEXTERNAL
#define H_KINO_SORTEXTERNAL 1

#include <stddef.h>
#include "KinoSearch/Util/Obj.r"
#include "KinoSearch/Util/MergeSort.h"

typedef struct kino_SortExRun kino_SortExRun;
typedef struct kino_SortExternal kino_SortExternal;
typedef struct KINO_SORTEXTERNAL_VTABLE KINO_SORTEXTERNAL_VTABLE;

struct kino_InvIndex;
struct kino_InStream;
struct kino_OutStream;
struct kino_ByteBuf;
struct kino_SegInfo;

#define KINO_SORTEX_DEFAULT_MEM_THRESHOLD 0x1000000

KINO_FINAL_CLASS("KinoSearch::Util::SortExternal", "SortEx",
    "KinoSearch::Util::Obj");

struct kino_SortExternal {
    KINO_SORTEXTERNAL_VTABLE *_;
    kino_u32_t refcount;

    struct kino_ByteBuf  **cache; /* item cache, incoming and outgoing */
    kino_u32_t             cache_cap;   /* allocated limit for cache */
    kino_u32_t             cache_elems; /* number of elems in cache */ 
    kino_u32_t             cache_pos;   /* index of current element */
    struct kino_ByteBuf  **scratch;     /* memory for use by mergesort */
    kino_u32_t             scratch_cap;     /* allocated limit for scratch */
    kino_u32_t             mem_threshold;   /* mem allowed for cache */
    kino_u32_t             cache_bytes;     /* mem occupied by cache */
    kino_u32_t             run_cache_limit; /* mem allowed each run cache */
    kino_SortExRun       **runs;
    kino_u32_t             num_runs;
    struct kino_OutStream *outstream;
    struct kino_InStream  *instream;
    struct kino_InvIndex  *invindex;
    struct kino_SegInfo   *seg_info;
};

/* Constructor. 
 */
KINO_FUNCTION(
kino_SortExternal*
kino_SortEx_new(struct kino_InvIndex *invindex, 
                struct kino_SegInfo *seg_info, 
                kino_u32_t mem_threshold));

/* Create a new ByteBuf and feed it into the SortEx.
 */
KINO_METHOD("Kino_SortEx_Feed",
void
kino_SortEx_feed(kino_SortExternal *self, char *ptr, kino_u32_t len));

/* Add a ByteBuf to the sort pool.  The SortEx object takes control of the
 * actual ByteBuf rather than performing a copy op, so the ByteBuf should not
 * be modified post-feeding.
 */
KINO_METHOD("Kino_SortEx_Feed_BB",
void
kino_SortEx_feed_bb(kino_SortExternal *self, struct kino_ByteBuf *bb));

/* Fetch the next sorted item from the sort pool.  sort_all() must be called
 * first.
 */
KINO_METHOD("Kino_SortEx_Fetch",
struct kino_ByteBuf*
kino_SortEx_fetch(kino_SortExternal *self));

/* Sort all items currently in the main cache.
 */
KINO_METHOD("Kino_SortEx_Sort_Cache",
void
kino_SortEx_sort_cache(kino_SortExternal *self));

/* Sort everything in memory and write the sorted elements to disk, creating a
 * SortExRun C object.
 */
KINO_METHOD("Kino_SortEx_Sort_Run",
void
kino_SortEx_sort_run(kino_SortExternal *self));

KINO_METHOD("Kino_SortEx_Destroy",
void
kino_SortEx_destroy(kino_SortExternal *self));

KINO_END_CLASS

#endif /* H_KINO_SORTEXTERNAL */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

