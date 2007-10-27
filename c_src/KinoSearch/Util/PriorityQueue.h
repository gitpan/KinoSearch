#ifndef H_KINO_PRIORITYQUEUE
#define H_KINO_PRIORITYQUEUE 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_PriorityQueue kino_PriorityQueue;
typedef struct KINO_PRIORITYQUEUE_VTABLE KINO_PRIORITYQUEUE_VTABLE;

KINO_CLASS("KinoSearch::Util::PriorityQueue", "PriQ", 
    "KinoSearch::Util::Obj");

struct kino_PriorityQueue {
    KINO_PRIORITYQUEUE_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    chy_u32_t               size;
    chy_u32_t               max_size;
    void                  **heap;
    kino_Obj_less_than_t    less_than;
    kino_Obj_free_elem_t    free_elem;
};

/* Constructor.
 */
kino_PriorityQueue*
kino_PriQ_new(chy_u32_t max_size, kino_Obj_less_than_t less_than, 
              kino_Obj_free_elem_t free_elem);

/* Initialize base elements.  Called by subclass constructors.
 */
void
kino_PriQ_init_base(kino_PriorityQueue *self, chy_u32_t max_size, 
                    kino_Obj_less_than_t less_than, 
                    kino_Obj_free_elem_t free_elem);

/* Add an element to the Queue if either...
 * a) the queue isn't full, or
 * b) the element belongs in the queue and should displace another
 */
chy_bool_t
kino_PriQ_insert(kino_PriorityQueue *self, void *element);
KINO_METHOD("Kino_PriQ_Insert");

/* Pop the *least* item off of the priority queue.
 */
void*
kino_PriQ_pop(kino_PriorityQueue *self);
KINO_FINAL_METHOD("Kino_PriQ_Pop");

/* Return the least item in the queue, but don't remove it.
 */
void*
kino_PriQ_peek(kino_PriorityQueue *self);
KINO_FINAL_METHOD("Kino_PriQ_Peek");

void
kino_PriQ_destroy(kino_PriorityQueue *self);
KINO_METHOD("Kino_PriQ_Destroy");

KINO_END_CLASS

#endif /* H_KINO_PRIORITYQUEUE */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

