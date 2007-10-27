#ifndef H_KINO_SORTEXTERNAL
#define H_KINO_SORTEXTERNAL 1

#include <stddef.h>
#include "KinoSearch/Util/Obj.r"
#include "KinoSearch/Util/MSort.h"

typedef struct kino_SortExternal kino_SortExternal;
typedef struct KINO_SORTEXTERNAL_VTABLE KINO_SORTEXTERNAL_VTABLE;

struct kino_InvIndex;
struct kino_InStream;
struct kino_OutStream;
struct kino_ByteBuf;
struct kino_SegInfo;
struct kino_SortExRun;

#define KINO_SORTEX_DEFAULT_MEM_THRESHOLD 0x1000000

KINO_CLASS("KinoSearch::Util::SortExternal", "SortEx",
    "KinoSearch::Util::Obj");

struct kino_SortExternal {
    KINO_SORTEXTERNAL_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    kino_MSort_compare_t    compare;
    kino_Obj               *context;
    kino_Obj              **cache;    /* item cache, incoming and outgoing */
    chy_u32_t               cache_cap;   /* allocated limit for cache */
    chy_u32_t               cache_max;   /* number of elems in cache */ 
    chy_u32_t               cache_tick;  /* index of current element */
    kino_Obj              **scratch;     /* memory for use by mergesort */
    chy_u32_t               scratch_cap; /* allocated limit for scratch */
    chy_u32_t               mem_thresh;  /* mem allowed for cache elems */
    chy_u32_t               consumed;    /* mem occupied by cache elems */
    struct kino_SortExRun **runs;
    chy_u32_t               num_runs;
    chy_bool_t              flipped;      /* force flip before fetch */ 
};

/* Initialize members vars defined by the SortExternal struct.
 */
void
kino_SortEx_init_base(kino_SortExternal *self, chy_u32_t mem_thresh, 
                      kino_MSort_compare_t compare);

/* Add an Obj to the sort pool.  The SortEx object takes control of the
 * Obj, so it should not be modified post-feeding.
 */
void
kino_SortEx_feed(kino_SortExternal *self, kino_Obj *obj, 
                 chy_u32_t bytes_this_obj);
KINO_METHOD("Kino_SortEx_Feed");

/* Abstract method.  Flip the sortex from write mode to read mode.
 */
void
kino_SortEx_flip(kino_SortExternal *self);
KINO_METHOD("Kino_SortEx_Flip");

/* Fetch the next sorted item from the sort pool.  SortEx_Flip must be called
 * first.  Returns NULL when the sortex has been exhausted.
 */
struct kino_Obj*
kino_SortEx_fetch(kino_SortExternal *self);
KINO_METHOD("Kino_SortEx_Fetch");

/* Preview the next item that Fetch will return, but don't pop it.
 */
struct kino_Obj*
kino_SortEx_peek(kino_SortExternal *self);
KINO_METHOD("Kino_SortEx_Peek");

/* Sort all items currently in the main cache.
 */
void
kino_SortEx_sort_cache(kino_SortExternal *self);
KINO_METHOD("Kino_SortEx_Sort_Cache");

/* Abstract method.  Flush all elements currently in the cache.  Presumably
 * this entails sorting everything, then writing the sorted elements
 * to disk and spawning an object which isa SortExRun to represent those
 * elements.
 */
void
kino_SortEx_flush(kino_SortExternal *self);
KINO_METHOD("Kino_SortEx_Flush");

/* Release items currently held in the cache, if any.  Reset all cache
 * variables (consumed, cache_max, etc).
 */
void
kino_SortEx_clear_cache(kino_SortExternal *self);
KINO_METHOD("Kino_SortEx_Clear_Cache");

/* Add a run to the sortex's collection.
 */
void
kino_SortEx_add_run(kino_SortExternal *self, struct kino_SortExRun *run);
KINO_METHOD("Kino_SortEx_Add_Run");

void
kino_SortEx_destroy(kino_SortExternal *self);
KINO_METHOD("Kino_SortEx_Destroy");

KINO_END_CLASS

#endif /* H_KINO_SORTEXTERNAL */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

