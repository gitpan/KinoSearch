/**
 * @class ScorerDocQueue ScorerDocQueue.r
 * @brief PriorityQueue for ordering Scorers by doc.
 *
 * ScorerDocQueue is designed to sort multiple scorers by document number and
 * aggregate scores based on which items in the queue share the current doc
 * number.  It is derived from PriorityQueue, but is not a subclass -- the
 * code has been unrolled for performance.
 */

#ifndef H_KINO_SCORERDOCQUEUE
#define H_KINO_SCORERDOCQUEUE 1

#include "KinoSearch/Util/Obj.r"
#include "KinoSearch/Search/Scorer.r"

/* A wrapper for a Scorer which caches the result of Scorer_Doc().
 */
typedef struct kino_HeapedScorerDoc {
    struct kino_Scorer *scorer;
    chy_u32_t           doc;
} kino_HeapedScorerDoc;

typedef struct kino_ScorerDocQueue kino_ScorerDocQueue;
typedef struct KINO_SCORERDOCQUEUE_VTABLE KINO_SCORERDOCQUEUE_VTABLE;

KINO_FINAL_CLASS("KinoSearch::Search::ScorerDocQueue", "ScorerDocQ", 
    "KinoSearch::Util::Obj");

struct kino_ScorerDocQueue {
    KINO_SCORERDOCQUEUE_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    kino_HeapedScorerDoc **heap;
    kino_HeapedScorerDoc **pool;    /**< Pool of HSDs to minimize mallocs */
    char                  *blob;    /**< single allocation for all HSDs */
    kino_HeapedScorerDoc  *top_hsd; /**< cached top elem */
    chy_u32_t              size;
    chy_u32_t              max_size;
};

/* Constructor.
 * 
 * @arg max_size The maximum number of Scorers the queue can hold.
 */
kino_ScorerDocQueue*
kino_ScorerDocQ_new(chy_u32_t max_size);

void
kino_ScorerDocQ_destroy(kino_ScorerDocQueue *self);
KINO_FINAL_METHOD("Kino_ScorerDocQ_Destroy");

void
kino_ScorerDocQ_put(kino_ScorerDocQueue *self, struct kino_Scorer *scorer);
KINO_FINAL_METHOD("Kino_ScorerDocQ_Put");

chy_bool_t
kino_ScorerDocQ_insert(kino_ScorerDocQueue *self, struct kino_Scorer *scorer);
KINO_FINAL_METHOD("Kino_ScorerDocQ_Insert");

/* Call Scorer_Next() on the top score and adjust the queue, removing the
 * Scorer if Scorer_Next() returns false. 
 */
chy_bool_t
kino_ScorerDocQ_top_next(kino_ScorerDocQueue *self);
KINO_FINAL_METHOD("Kino_ScorerDocQ_Top_Next");

/* Call Scorer_Skip_To() on the top scorer and adjust the queue, removing the
 * Scorer if Scorer_Skip_To() returns false. 
 */
chy_bool_t
kino_ScorerDocQ_top_skip_to(kino_ScorerDocQueue *self, chy_u32_t target);
KINO_FINAL_METHOD("Kino_ScorerDocQ_Top_Skip_To");

/* Pop the scorer with the lowest doc off the top of the queue.
 */
struct kino_Scorer*
kino_ScorerDocQ_pop(kino_ScorerDocQueue *self);
KINO_FINAL_METHOD("Kino_ScorerDocQ_Pop");

/* Reorder the queue after the value of Scorer_Doc() for the least Scorer has
 * changed.
 */
void
kino_ScorerDocQ_adjust_top(kino_ScorerDocQueue *self);
KINO_FINAL_METHOD("Kino_ScorerDocQ_Adjust_Top");

KINO_END_CLASS

/* Get the Scorer at the top of the queue -- with the least document number.
 * Don't call this (or any of the other peeks) when Queue is empty.
 */
#define KINO_SCORERDOCQ_PEEK(self) (self)->top_hsd->scorer

/* Get the document number of the Scorer at the front of the queue.
 */
#define KINO_SCORERDOCQ_PEEK_DOC(self) (self)->top_hsd->doc

/* Get the Tally from the Scorer at the front of the queue.  Note that this is
 * not the same as the aggregate Tally for the doc.
 */
#define KINO_SCORERDOCQ_PEEK_TALLY(self) \
    Kino_Scorer_Tally((self)->top_hsd->scorer)

/* Return the number of Scorers in the queue.
 */
#define KINO_SCORERDOCQ_SIZE(self) (self)->size

#ifdef KINO_USE_SHORT_NAMES
  #define HeapedScorerDoc              kino_HeapedScorerDoc
  #define SCORERDOCQ_PEEK(self)        KINO_SCORERDOCQ_PEEK(self)
  #define SCORERDOCQ_PEEK_DOC(self)    KINO_SCORERDOCQ_PEEK_DOC(self)
  #define SCORERDOCQ_PEEK_TALLY(self)  KINO_SCORERDOCQ_PEEK_TALLY(self)
  #define SCORERDOCQ_SIZE(self)        KINO_SCORERDOCQ_SIZE(self)
#endif

#endif /* H_KINO_SCORERDOCQUEUE */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

