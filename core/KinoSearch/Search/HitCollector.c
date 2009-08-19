#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/HitCollector.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Search/Matcher.h"
#include "KinoSearch/Util/I32Array.h"

HitCollector*
HC_init(HitCollector *self)
{
    ABSTRACT_CLASS_CHECK(self, HITCOLLECTOR);
    self->reader  = NULL;
    self->matcher = NULL;
    self->base    = 0;
    return self;
}

void
HC_destroy(HitCollector *self)
{
    DECREF(self->reader);
    DECREF(self->matcher);
    SUPER_DESTROY(self, HITCOLLECTOR);
}

void
HC_set_reader(HitCollector *self, SegReader *reader)
{
    DECREF(self->reader);
    self->reader = reader ? (SegReader*)INCREF(reader) : NULL;
}

void
HC_set_matcher(HitCollector *self, Matcher *matcher)
{
    DECREF(self->matcher);
    self->matcher = matcher ? (Matcher*)INCREF(matcher) : NULL;
}

void
HC_set_base(HitCollector *self, i32_t base)
{
    self->base = base;
}

BitCollector*
BitColl_new(BitVector *bit_vec) 
{
    BitCollector *self = (BitCollector*)VTable_Make_Obj(BITCOLLECTOR);
    return BitColl_init(self, bit_vec);
}

BitCollector*
BitColl_init(BitCollector *self, BitVector *bit_vec) 
{
    HC_init((HitCollector*)self);
    self->bit_vec = (BitVector*)INCREF(bit_vec);
    return self;
}

void
BitColl_destroy(BitCollector *self)
{
    DECREF(self->bit_vec);
    SUPER_DESTROY(self, BITCOLLECTOR);
}

void
BitColl_collect(BitCollector *self, i32_t doc_id) 
{
    /* Add the doc_id to the BitVector. */
    BitVec_Set(self->bit_vec, doc_id);
}

bool_t
BitColl_need_score(BitCollector *self) 
{
    UNUSED_VAR(self);
    return false;
}

OffsetCollector*
OffsetColl_new(HitCollector *inner_coll, i32_t offset) 
{
    OffsetCollector *self 
        = (OffsetCollector*)VTable_Make_Obj(OFFSETCOLLECTOR);
    return OffsetColl_init(self, inner_coll, offset);
}

OffsetCollector*
OffsetColl_init(OffsetCollector *self, HitCollector *inner_coll, i32_t offset)
{
    HC_init((HitCollector*)self);
    self->offset     = offset;
    self->inner_coll = (HitCollector*)INCREF(inner_coll);
    return self;
}

void
OffsetColl_destroy(OffsetCollector *self)
{
    DECREF(self->inner_coll);
    SUPER_DESTROY(self, OFFSETCOLLECTOR);
}

void
OffsetColl_set_reader(OffsetCollector *self, SegReader *reader)
{
    HC_Set_Reader(self->inner_coll, reader);
}

void
OffsetColl_set_base(OffsetCollector *self, i32_t base)
{
    HC_Set_Base(self->inner_coll, base);
}

void
OffsetColl_set_matcher(OffsetCollector *self, Matcher *matcher)
{
    HC_Set_Matcher(self->inner_coll, matcher);
}

void
OffsetColl_collect(OffsetCollector *self, i32_t doc_id) 
{
    HC_Collect(self->inner_coll, (doc_id + self->offset));
}

bool_t
OffsetColl_need_score(OffsetCollector *self) 
{
    return HC_Need_Score(self->inner_coll);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

