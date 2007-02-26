#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_HITCOLLECTOR_VTABLE
#include "KinoSearch/Search/HitCollector.r"

#include "KinoSearch/Util/BitVector.r"
#include "KinoSearch/Util/IntMap.r"

typedef struct OffsCollData {
    kino_u32_t    offset;
    HitCollector *inner_coll;
} OffsCollData;

typedef struct FiltCollData {
    BitVector    *bit_vec;
    HitCollector *inner_coll;
} FiltCollData;

typedef struct RangeCollData {
    i32_t         lower_bound;
    i32_t         upper_bound;
    IntMap       *sort_cache;
    HitCollector *inner_coll;
} RangeCollData;

static void
HC_OffsColl_collect(HitCollector *self, u32_t doc_num, float score);

static void
HC_OffsColl_release(HitCollector *self);

static void
HC_BitColl_collect(HitCollector *self, u32_t doc_num, float score);

static void
HC_BitColl_release(HitCollector *self);

static void 
HC_FiltColl_collect(HitCollector *self, u32_t doc_num, float score);

static void
HC_FiltColl_release(HitCollector *self);

static void
HC_RangeColl_collect(HitCollector *self, u32_t doc_num, float score);

static void
HC_RangeColl_release(HitCollector *self);


HitCollector*
HC_new(kino_HC_collect_t collect, kino_HC_release_t release, void *data)
{
    CREATE(self, HitCollector, HITCOLLECTOR);
    self->collect = collect;
    self->release = release;
    self->data    = data;
    return self;
}

void
HC_destroy(HitCollector *self) 
{
    self->release(self);
    free(self);
}

HitCollector*
HC_new_bit_coll(BitVector *bits) 
{
    REFCOUNT_INC(bits);
    return HC_new(HC_BitColl_collect, HC_BitColl_release, bits);
}

static void
HC_BitColl_collect(HitCollector *self, u32_t doc_num, float score) 
{
    UNUSED_VAR(score);

    /* add the doc_num to the BitVector */
    BitVec_Set((BitVector*)self->data, doc_num);
}

static void
HC_BitColl_release(HitCollector *self)
{
    REFCOUNT_DEC((BitVector*)self->data);
}

HitCollector*
HC_new_offset_coll(HitCollector *inner_coll, u32_t offset) 
{
    OffsCollData *data = MALLOCATE(1, OffsCollData);
    data->offset = offset;
    data->inner_coll = inner_coll;
    REFCOUNT_INC(inner_coll);
    return HC_new(HC_OffsColl_collect, HC_OffsColl_release, data);
}

static void
HC_OffsColl_collect(HitCollector *self, u32_t doc_num, float score) 
{
    OffsCollData *const data = (OffsCollData*)self->data;
    data->inner_coll->collect(data->inner_coll, (doc_num + data->offset), 
        score);
}

static void
HC_OffsColl_release(HitCollector *self)
{
    OffsCollData *const data = (OffsCollData*)self->data;
    REFCOUNT_DEC(data->inner_coll);
    free(data);
}


HitCollector*
HC_new_filt_coll(HitCollector *inner_coll, BitVector *bit_vec)
{
    FiltCollData *data = MALLOCATE(1, FiltCollData);
    data->inner_coll = inner_coll;
    data->bit_vec    = bit_vec;
    REFCOUNT_INC(inner_coll);
    REFCOUNT_INC(bit_vec);
    return HC_new(HC_FiltColl_collect, HC_FiltColl_release, data);
}

static void 
HC_FiltColl_collect(HitCollector *self, u32_t doc_num, float score)
{
    FiltCollData *const data = (FiltCollData*)self->data;
    if (BitVec_Get(data->bit_vec, doc_num)) {
        data->inner_coll->collect(data->inner_coll, doc_num, score);
    }
}

static void
HC_FiltColl_release(HitCollector *self)
{
    FiltCollData *const data = (FiltCollData*)self->data;
    REFCOUNT_DEC(data->inner_coll);
    REFCOUNT_DEC(data->bit_vec);
    free(data);
}

HitCollector*
HC_new_range_coll(HitCollector *inner_coll, IntMap *sort_cache,
                  i32_t lower_bound, i32_t upper_bound)
{
    RangeCollData *const data = MALLOCATE(1, RangeCollData);

    /* assign */
    REFCOUNT_INC(sort_cache);
    REFCOUNT_INC(inner_coll);
    data->inner_coll  = inner_coll;
    data->sort_cache  = sort_cache;
    data->lower_bound = lower_bound;
    data->upper_bound = upper_bound;

    return HC_new(HC_RangeColl_collect, HC_RangeColl_release, data);
}

static void
HC_RangeColl_release(HitCollector *self)
{
    RangeCollData *const data = (RangeCollData*)self->data; 
    REFCOUNT_DEC(data->sort_cache);
    REFCOUNT_DEC(data->inner_coll);
    free(data);
}

static void 
HC_RangeColl_collect(HitCollector *self, u32_t doc_num, float score)
{
    RangeCollData *const data = (RangeCollData*)self->data; 
    const i32_t locus = IntMap_Get(data->sort_cache, doc_num);

    if (locus >= data->lower_bound && locus <= data->upper_bound) {
        data->inner_coll->collect(data->inner_coll, doc_num, score);
    }
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

