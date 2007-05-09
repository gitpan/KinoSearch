/**
 * @class KinoSearch::Util::SortExRun SortExRun.r
 * @brief Base class for externally sorted runs.
 *
 * Abstract base class representing a sorted run created by a SortExternal
 * object.
 * 
 */
#ifndef H_KINO_SORTEXRUN
#define H_KINO_SORTEXRUN 1

#include <stddef.h>
#include "KinoSearch/Util/Obj.r"
#include "KinoSearch/Util/MSort.h"

typedef struct kino_SortExRun kino_SortExRun;
typedef struct KINO_SORTEXRUN_VTABLE KINO_SORTEXRUN_VTABLE;

KINO_CLASS("KinoSearch::Util::SortExRun", "SortExRun",
    "KinoSearch::Util::Obj");

struct kino_SortExRun {
    KINO_SORTEXRUN_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    kino_MSort_compare_t   compare;
    kino_Obj              *context;
    kino_Obj             **cache;
    chy_u32_t              cache_cap;
    chy_u32_t              cache_max;
    chy_u32_t              cache_tick;
    chy_u32_t              slice_size;
};

/* Initialize members in SortExRun struct.
 */
void
kino_SortExRun_init_base(kino_SortExRun *self, kino_MSort_compare_t compare);

/* Abstract method. Recover elements from disk.  Return the number of elements
 * recovered.
 */
chy_u32_t
kino_SortExRun_refill(kino_SortExRun *self);
KINO_METHOD("Kino_SortExRun_Refill");

/* Allocate more memory to the Run's cache.
 */
void
kino_SortExRun_grow_cache(kino_SortExRun *self, chy_u32_t new_cache_cap);
KINO_METHOD("Kino_SortExRun_Grow_Cache");

/* Return the cache item with the highest sort value currently held in memory.
 * Calling this method when there are no cached items is invalid.
 */
kino_Obj*
kino_SortExRun_peek_last(kino_SortExRun *self);
KINO_FINAL_METHOD("Kino_SortExRun_Peek_Last");

/* Prepare to pop a "slice" of the cache: all elements which are less than or
 * equal to [endpost].  Returns the number of elements which will be popped.
 */
chy_u32_t
kino_SortExRun_prepare_slice(kino_SortExRun *self, kino_Obj *endpost);
KINO_FINAL_METHOD("Kino_SortExRun_Prepare_Slice");

/* Yield the slice of the cache indicated by a prior call to Prepare_Slice.
 * Returns a pointer to the elements, and placed the number of elements popped
 * into [slice_size].
 */
kino_Obj**
kino_SortExRun_pop_slice(kino_SortExRun *self, chy_u32_t *slice_size);
KINO_FINAL_METHOD("Kino_SortExRun_Pop_Slice");

/* Release existing cache elements, if any.  Reset cache vars.
 */
void
kino_SortExRun_clear_cache(kino_SortExRun *self);
KINO_METHOD("Kino_SortExRun_Clear_Cache");

KINO_END_CLASS

#define KINO_SORTEXRUN_CACHE_COUNT(_run) \
    (_run->cache_max - _run->cache_tick)

#ifdef KINO_USE_SHORT_NAMES
  #define SORTEXRUN_CACHE_COUNT(_run)     KINO_SORTEXRUN_CACHE_COUNT(_run)
#endif 

#endif /* H_KINO_SORTEXRUN */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

