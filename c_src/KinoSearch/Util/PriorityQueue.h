#ifndef H_KINO_PRIORITYQUEUE
#define H_KINO_PRIORITYQUEUE 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_PriorityQueue kino_PriorityQueue;
typedef struct KINO_PRIORITYQUEUE_VTABLE KINO_PRIORITYQUEUE_VTABLE;

/* Comparison function.  
 */
typedef kino_bool_t 
(*kino_PriQ_less_than_t)(const void *a, const void *b);

/* Dispose of discarded elements.
 */
typedef void
(*kino_PriQ_free_elem_t)(void *elem);

#ifdef KINO_USE_SHORT_NAMES
  #define PriQ_less_than_t kino_PriQ_less_than_t
  #define PriQ_free_elem_t kino_PriQ_free_elem_t
#endif /* KINO_USE_SHORT_NAMES */

KINO_CLASS("KinoSearch::Util::PriorityQueue", "PriQ", 
    "KinoSearch::Util::Obj");

struct kino_PriorityQueue {
    KINO_PRIORITYQUEUE_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    kino_u32_t              size;
    kino_u32_t              max_size;
    void                  **heap;
    kino_PriQ_less_than_t   less_than;
    kino_PriQ_free_elem_t   free_elem;
};


/* Constructor.
 */
KINO_FUNCTION(
kino_PriorityQueue*
kino_PriQ_new(kino_u32_t max_size, kino_PriQ_less_than_t less_than, 
              kino_PriQ_free_elem_t free_elem));

/* Initialize base elements.  Called by subclass constructors.
 */
KINO_FUNCTION(
void
kino_PriQ_init_base(kino_PriorityQueue *self, kino_u32_t max_size, 
                    kino_PriQ_less_than_t less_than, 
                    kino_PriQ_free_elem_t free_elem));

/* Add an element to the Queue if either...
 * a) the queue isn't full, or
 * b) the element belongs in the queue and should displace another
 */
KINO_METHOD("Kino_PriQ_Insert",
kino_bool_t
kino_PriQ_insert(kino_PriorityQueue *self, void *element));

/* Pop the *least* item off of the priority queue.
 */
KINO_METHOD("Kino_PriQ_Pop",
void*
kino_PriQ_pop(kino_PriorityQueue *self));

/* Return the least item in the queue, but don't remove it.
 */
KINO_METHOD("Kino_PriQ_Peek",
void*
kino_PriQ_peek(kino_PriorityQueue *self));

KINO_METHOD("Kino_PriQ_Destroy",
void
kino_PriQ_destroy(kino_PriorityQueue *self));

KINO_END_CLASS

#endif /* H_KINO_PRIORITYQUEUE */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

