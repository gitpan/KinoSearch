#include "KinoSearch/Util/ToolSet.h"

#include <string.h>

#define KINO_WANT_PRIORITYQUEUE_VTABLE
#include "KinoSearch/Util/PriorityQueue.r"

/* Add an element to the heap.  Throw an error if too many elements 
 * are added.
 */
static void
put(PriorityQueue *self, void *element);

/* Free all the elements in the heap and set size to 0.
 */
static void 
clear(PriorityQueue *self);

/* Heap adjuster. 
 */
static void
up_heap(PriorityQueue *self);

/* Heap adjuster.  Should be called when the item at the top changes. 
 */
static void
down_heap(PriorityQueue *self);

PriorityQueue*
PriQ_new(u32_t max_size, Obj_less_than_t less_than, 
         Obj_free_elem_t free_elem)
{
    CREATE(self, PriorityQueue, PRIORITYQUEUE);
    PriQ_init_base(self, max_size, less_than, free_elem);
    return self;
}

void
PriQ_init_base(PriorityQueue *self, u32_t max_size, 
               Obj_less_than_t less_than, Obj_free_elem_t free_elem)
{
    u32_t heap_size = max_size + 1;

    /* init */
    self->size = 0;

    /* assign */
    self->max_size    = max_size;
    self->less_than   = less_than;
    self->free_elem   = free_elem;

    /* allocate space for the heap, assign all slots to NULL */
    self->heap = CALLOCATE(heap_size, void*);
}

void
PriQ_destroy(PriorityQueue *self) 
{
    clear(self);
    free(self->heap);
    free(self);
}

static void
put(PriorityQueue *self, void *element) 
{
    /* increment size */
    if (self->size >= self->max_size) {
        CONFESS("PriorityQueue exceeded max_size: %d %d", self->size, 
            self->max_size);
    }
    self->size++;

    /* put element into heap */
    self->heap[ self->size ] = element;

    /* adjust heap */
    up_heap(self);
}

bool_t
PriQ_insert(PriorityQueue *self, void *element) 
{
    /* absorb element if there's a vacancy */
    if (self->size < self->max_size) {
        put(self, element);
        return true;
    }
    /* otherwise, compete for the slot */
    else {
        void *scratch = PriQ_Peek(self);
        if( self->size > 0 && !self->less_than(element, scratch)) {
            /* if the new element belongs in the queue, replace something */
            self->free_elem( self->heap[1] );
            self->heap[1] = element;
            down_heap(self);
            return true;
        }
        else {
            self->free_elem(element);
            return false;
        }
    }
}

void*
PriQ_pop(PriorityQueue *self) 
{
    if (self->size > 0) {
        /* mortalize the first value and save it */
        void *result = self->heap[1];

        /* move last to first and adjust heap */
        self->heap[1] = self->heap[ self->size ];
        self->heap[ self->size ] = NULL;
        self->size--;
        down_heap(self);

        return result;
    }
    else {
        return NULL;
    }
}

void*
PriQ_peek(PriorityQueue *self) 
{
    if (self->size > 0) {
        return self->heap[1];
    }
    else {
        return NULL;
    }
}

static void 
clear(PriorityQueue *self) 
{
    u32_t i;
    void **elem_ptr = (self->heap + 1);

    /* node 0 is held empty, to make the algo clearer */
    for (i = 1; i <= self->size; i++) {
        self->free_elem(*elem_ptr);
        *elem_ptr = NULL;
        elem_ptr++;
    }   
    self->size = 0;
}

static void
up_heap(PriorityQueue *self) 
{
    const Obj_less_than_t less_than = self->less_than;
    u32_t i = self->size;
    u32_t j = i >> 1;
    void *const node = self->heap[i]; /* save bottom node */

    while (    j > 0 
            && less_than(node, self->heap[j])
    ) {
        self->heap[i] = self->heap[j];
        i = j;
        j = j >> 1;
    }
    self->heap[i] = node;
}

static void
down_heap(PriorityQueue *self) 
{
    const Obj_less_than_t less_than = self->less_than;
    u32_t i = 1;
    u32_t j = i << 1;
    u32_t k = j + 1;
    void *node = self->heap[i]; /* save top node */

    /* find smaller child */
    if (   k <= self->size 
        && less_than(self->heap[k], self->heap[j])
    ) {
        j = k;
    }

    while (   j <= self->size 
           && less_than(self->heap[j], node)
    ) {
        self->heap[i] = self->heap[j];
        i = j;
        j = i << 1;
        k = j + 1;
        if (   k <= self->size 
            && less_than(self->heap[k], self->heap[j])
        ) {
            j = k;
        }
    }
    self->heap[i] = node;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

