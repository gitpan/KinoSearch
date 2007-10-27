#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_FIELDDOCCOLLATOR_VTABLE
#include "KinoSearch/Search/FieldDocCollator.r"

#include "KinoSearch/Search/FieldDoc.r"
#include "KinoSearch/Util/IntMap.r"

FieldDocCollator*
FDocCollator_new()
{
    CREATE(self, FieldDocCollator, FIELDDOCCOLLATOR);

    self->cap         = 0;
    self->size        = 0;
    self->sort_caches = NULL;
    self->reversed    = NULL;

    return self;
}

void
FDocCollator_destroy(FieldDocCollator *self)
{
    u32_t i;

    for (i = 0; i < self->size; i++) {
        REFCOUNT_DEC(self->sort_caches[i]);
    }
    free(self->sort_caches);
    free(self->reversed);
    free(self);
}

void
FDocCollator_add(FieldDocCollator *self, IntMap *sort_cache, bool_t rev)
{
    /* allocate space */
    if (self->size >= self->cap) {
        self->cap += 10;
        self->sort_caches 
            = REALLOCATE(self->sort_caches, self->cap, IntMap*);
        self->reversed = REALLOCATE(self->reversed, self->cap, bool_t);
    }

    self->sort_caches[ self->size ] = REFCOUNT_INC(sort_cache);
    self->reversed[ self->size ]    = rev;
    self->size++;
}

bool_t
FDocCollator_less_than(const void *va, const void *vb)
{
    FieldDoc *const a = (FieldDoc*)va;
    FieldDoc *const b = (FieldDoc*)vb;
    FieldDocCollator *const self = a->collator; /* extract self */

    return FDocCollator_compare(self, a->doc_num, a->score, 
                                      b->doc_num, b->score);
}

bool_t
FDocCollator_compare(FieldDocCollator *self, u32_t doc_num_a, float score_a, 
                     u32_t doc_num_b, float score_b)
{
    IntMap **const sort_caches  = self->sort_caches;
    bool_t *const reversed         = self->reversed;
    u32_t i;

    for (i = 0; i < self->size; i++) {
        /* TODO: unroll for speed */
        const i32_t sort_num_a = IntMap_Get(sort_caches[i], doc_num_a);
        const i32_t sort_num_b = IntMap_Get(sort_caches[i], doc_num_b);
        
        if (sort_num_a != sort_num_b) {
            /* This appears to be backwards, but it isn't.  Things have to be
             * inverted because we're comparing pre-prepared sort numbers.
             */
            bool_t retval = sort_num_a > sort_num_b;
            if (reversed[i])
                return !retval;
            else 
                return retval;
        }
    }

    /* break ties by score, then by doc num, so sort is stable per reader */
    if (score_a != score_b)
        return score_a < score_b;
    else 
        return doc_num_a < doc_num_b;
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

