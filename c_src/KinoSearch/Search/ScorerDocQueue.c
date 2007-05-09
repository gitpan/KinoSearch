#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCORERDOCQUEUE_VTABLE
#include "KinoSearch/Search/ScorerDocQueue.r"

static void 
clear(ScorerDocQueue *self);

static bool_t
check_adjust_else_pop(ScorerDocQueue *self, bool_t condition);

static void
up_heap(ScorerDocQueue *self);

static void
down_heap(ScorerDocQueue *self);

ScorerDocQueue*
ScorerDocQ_new(u32_t max_size) 
{
    size_t amount_to_malloc;
    u32_t i;
    CREATE(self, ScorerDocQueue, SCORERDOCQUEUE);

    /* init */
    self->size = 0;

    /* assign */
    self->max_size = max_size;

    /* allocate */
    self->heap = CALLOCATE(max_size + 1, HeapedScorerDoc*);

    /* encourage CPU cache hits with single allocation for all HSDs */
    amount_to_malloc = (max_size + 1) * sizeof(HeapedScorerDoc);
    self->blob = MALLOCATE(amount_to_malloc, char);

    /* create a pool of HSDs. */
    self->pool = CALLOCATE(max_size + 1, HeapedScorerDoc*);
    for (i = 1; i <= self->max_size; i++) {
        size_t offset = i * sizeof(HeapedScorerDoc);
        HeapedScorerDoc *hsd = (HeapedScorerDoc*)(self->blob + offset);
        self->pool[i] = hsd;
    }
    
    return self;
}

void
ScorerDocQ_destroy(ScorerDocQueue *self)
{
    clear(self);
    free(self->blob);
    free(self->pool);
    free(self->heap);
    free(self);
}

static void 
clear(ScorerDocQueue *self) 
{
    HeapedScorerDoc **const heap = self->heap;
    HeapedScorerDoc **const pool = self->pool;

    /* node 0 is held empty, to make the algo clearer */
    for ( ; self->size > 0; self->size--) {
        HeapedScorerDoc *hsd = heap[ self->size ];
        heap[ self->size ] = NULL;
        REFCOUNT_DEC(hsd->scorer);

        /* put HSD back in pool */
        pool[ self->size ] = hsd;
    }   
}

void
ScorerDocQ_put(ScorerDocQueue *self, struct Scorer *scorer)
{
    HeapedScorerDoc **const heap = self->heap;
    HeapedScorerDoc **const pool = self->pool;
    HeapedScorerDoc *hsd;

    /* increment size */
    if (self->size >= self->max_size) {
        CONFESS("ScorerDocQueue exceeded max_size: %d %d", self->size, 
            self->max_size);
    }
    self->size++;

    /* put element into heap */
    REFCOUNT_INC(scorer);
    hsd         = pool[ self->size ];
    hsd->scorer = scorer;
    hsd->doc    = Scorer_Doc(scorer);
    heap[ self->size ] = hsd;

    /* adjust heap */
    up_heap(self);
}

bool_t
ScorerDocQ_insert(ScorerDocQueue *self, struct Scorer *scorer)
{
    /* absorb element if there's a vacancy */
    if (self->size < self->max_size) {
        ScorerDocQ_Put(self, scorer);
        return true;
    }
    /* otherwise, compete for the slot */
    else {
        HeapedScorerDoc *const top_hsd = self->top_hsd;
        const u32_t doc_num = Scorer_Doc(scorer);
        if (   self->size > 0
            && !(doc_num < top_hsd->doc)
        ) {
            /* if the new element belongs in the queue, displace top_hsd */
            REFCOUNT_DEC(top_hsd->scorer);
            REFCOUNT_INC(scorer);
            top_hsd->scorer = scorer;
            top_hsd->doc    = Scorer_Doc(scorer);
            down_heap(self);
            return true;
        }
        else {
            return false;
        }
    }
}

static bool_t
check_adjust_else_pop(ScorerDocQueue *self, bool_t condition)
{
    HeapedScorerDoc *const top_hsd = self->top_hsd;

    if (condition) { /* inlined adjust_top */
        HeapedScorerDoc *const top_hsd = self->top_hsd;
        top_hsd->doc = Scorer_Doc(top_hsd->scorer);
    }
    else { /* inlined pop */
        HeapedScorerDoc *const last_hsd = self->heap[ self->size ];

        /* last to first */
        REFCOUNT_DEC(top_hsd->scorer);
        top_hsd->scorer = last_hsd->scorer;
        top_hsd->doc    = last_hsd->doc;
        self->heap[ self->size ] = NULL;

        /* put back in pool */
        self->pool[ self->size ] = last_hsd;

        self->size--;
    }

    /* move Queue no matter what */
    down_heap(self);

    return condition;
}

bool_t
ScorerDocQ_top_next(ScorerDocQueue *self)
{
    const bool_t condition = Scorer_Next(self->top_hsd->scorer);
    return check_adjust_else_pop(self, condition);
}

bool_t
ScorerDocQ_top_skip_to(ScorerDocQueue *self, u32_t target)
{
    const bool_t condition = Scorer_Skip_To(self->top_hsd->scorer, target);
    return check_adjust_else_pop(self, condition);
}

Scorer*
ScorerDocQ_pop(ScorerDocQueue *self)
{
    HeapedScorerDoc *const top_hsd = self->top_hsd;
    Scorer *retval = top_hsd->scorer;
    HeapedScorerDoc *const last_hsd = self->heap[ self->size ];

    /* last to first */
    REFCOUNT_DEC(top_hsd->scorer);
    top_hsd->scorer = last_hsd->scorer;
    top_hsd->doc    = last_hsd->doc;
    self->heap[ self->size ] = NULL;

    /* put back in pool */
    self->pool[ self->size ] = last_hsd;

    /* decrement size and reorder queue */
    self->size--;
    down_heap(self);

    return retval;
}

/* Reorder the queue after the value of Scorer_Doc() for the least Scorer has
 * changed.
 */
void
ScorerDocQ_adjust_top(ScorerDocQueue *self)
{
    HeapedScorerDoc *const top_hsd = self->top_hsd;
    top_hsd->doc = Scorer_Doc(top_hsd->scorer);
    down_heap(self);
}

static void
up_heap(ScorerDocQueue *self) 
{
    HeapedScorerDoc **const heap = self->heap;
    u32_t i = self->size;
    u32_t j = i >> 1;
    HeapedScorerDoc *const node = heap[i]; /* save bottom node */

    while (j > 0 && node->doc < heap[j]->doc) {
        heap[i] = heap[j];
        i = j;
        j = j >> 1;
    }
    heap[i] = node;
    self->top_hsd = heap[1];
}

static void
down_heap(ScorerDocQueue *self) 
{
    HeapedScorerDoc **const heap = self->heap;
    u32_t i = 1;
    u32_t j = i << 1;
    u32_t k = j + 1;
    HeapedScorerDoc *const node = heap[i]; /* save top node */

    /* find smaller child */
    if (k <= self->size && heap[k]->doc < heap[j]->doc) {
        j = k;
    }

    while (j <= self->size && heap[j]->doc < node->doc) {
        heap[i] = heap[j];
        i = j;
        j = i << 1;
        k = j + 1;
        if (k <= self->size && heap[k]->doc < heap[j]->doc) {
            j = k;
        }
    }
    heap[i] = node;
    
    self->top_hsd = heap[1];
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
