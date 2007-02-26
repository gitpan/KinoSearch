#ifndef H_KINO_HITCOLLECTOR
#define H_KINO_HITCOLLECTOR 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_HitCollector kino_HitCollector;
typedef struct KINO_HITCOLLECTOR_VTABLE KINO_HITCOLLECTOR_VTABLE;

struct kino_BitVector;
struct kino_IntMap;

typedef void 
(*kino_HC_collect_t)(kino_HitCollector*, kino_u32_t doc_num, float score);

typedef void
(*kino_HC_release_t)(kino_HitCollector*);

#ifdef KINO_USE_SHORT_NAMES
  #define HC_collect_t kino_HC_collect_t
  #define HC_release_t kino_HC_release_t
#endif

KINO_CLASS("KinoSearch::Search::HitCollector", "HC", "KinoSearch::Util::Obj");

struct kino_HitCollector {
    KINO_HITCOLLECTOR_VTABLE *_;
    kino_u32_t refcount;
    kino_HC_collect_t collect;
    kino_HC_release_t release;
    void *data;
};

/* Constructor.  
 *
 * The three arguments will be assigned to the members of a newly allocated
 * HitCollector struct.  release() will be called during object destruction,
 * just before the HitCollector struct is freed.  [data] can used to store
 * arbitrary data needed during the process of collecting hits.
 */
KINO_FUNCTION(
kino_HitCollector *
kino_HC_new(kino_HC_collect_t collect, kino_HC_release_t release, void *data));

/* Return a HitCollector which sets a set bit for each matching doc number
 * (scores are irrelevant).
 */
KINO_FUNCTION(
kino_HitCollector*
kino_HC_new_bit_coll(struct kino_BitVector *bits));

/* Wrap another HitCollector, adding a constant offset to each document
 * number.  Useful when combining results from multiple independent indexes.
 */
KINO_FUNCTION(
kino_HitCollector*
kino_HC_new_offset_coll(kino_HitCollector *inner_coll, kino_u32_t offset));


/* Wrap another HitCollector, only allowing the inner collector to "see"
 * doc_num/score pairs which make it through the filter.
 */
KINO_FUNCTION(
kino_HitCollector*
kino_HC_new_filt_coll(kino_HitCollector *inner_coll, 
                      struct kino_BitVector *bit_vec));

/* Wrap another HitCollector, filtering out documents whose position in the
 * sort cache lies outside * the given range. The upper and lower bounds are
 * inclusive.
 */
KINO_FUNCTION(
kino_HitCollector*
kino_HC_new_range_coll(kino_HitCollector *inner_coll, 
                       struct kino_IntMap *sort_cache,
                       kino_i32_t lower_bound, kino_i32_t upper_bound));

KINO_METHOD("Kino_HC_Destroy",
void
kino_HC_destroy(kino_HitCollector *self));

KINO_END_CLASS

#endif /* H_KINO_HITCOLLECTOR */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

