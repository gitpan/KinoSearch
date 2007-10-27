/**
 * @class KinoSearch::Posting  Posting.r
 * @brief Vessel holding statistical data for a posting.
 */
#ifndef H_KINO_POSTING
#define H_KINO_POSTING 1

#include "KinoSearch/Util/Stepper.r"

struct kino_PostingPool;
struct kino_FieldSpec;
struct kino_TokenBatch;
struct kino_PostingList;
struct kino_Scorer;
struct kino_Similarity;
struct kino_RawPosting;
struct kino_MemoryPool;

typedef struct kino_Posting kino_Posting;
typedef struct KINO_POSTING_VTABLE KINO_POSTING_VTABLE;

KINO_CLASS("KinoSearch::Posting", "Post", "KinoSearch::Util::Stepper");

struct kino_Posting {
    KINO_POSTING_VTABLE *_;
    KINO_STEPPER_MEMBER_VARS;
    struct kino_Similarity *sim;
    chy_u32_t               doc_num;     /**< document number */
};

/* Abstract method.
 *
 * Create a RawPosting object, suitable for index-time sorting.  
 *
 * Updates the state of the document number, but nothing else.
 */
struct kino_RawPosting*
kino_Post_read_raw(kino_Posting *self, struct kino_InStream *instream,
                   chy_u32_t last_doc_num, struct kino_ByteBuf *term_text, 
                   struct kino_MemoryPool *mem_pool);
KINO_METHOD("Kino_Post_Read_Raw");

/* Abstract method.
 *
 * Process a TokenBatch into RawPosting objects and add them all to the
 * supplied PostingPool.
 */
void
kino_Post_add_batch_to_pool(kino_Posting *self, 
                            struct kino_PostingPool *post_pool, 
                            struct kino_TokenBatch *batch, 
                            struct kino_FieldSpec *fspec, 
                            chy_u32_t doc_num, float doc_boost, 
                            float length_norm);
KINO_METHOD("Kino_Post_Add_Batch_To_Pool");

/* Abstract method.
 * 
 * Prepare the posting to start reading after a seek.
 */
void
kino_Post_reset(kino_Posting *self, chy_u32_t doc_num);
KINO_METHOD("Kino_Post_Reset");

/* Abstract method.
 * 
 * Factory method for creating a Scorer.
 */
struct kino_Scorer*
kino_Post_make_scorer(kino_Posting *self, struct kino_Similarity *sim,
                      struct kino_PostingList *plist,
                      void *weight, float weight_val);
KINO_METHOD("Kino_Post_Make_Scorer");

/* Abstract method.
 * 
 * Like Clone, but takes an additional Similarity argument.
 */
kino_Posting*
kino_Post_dupe(kino_Posting *self, struct kino_Similarity *sim);
KINO_METHOD("Kino_Post_Dupe");

void
kino_Post_destroy(kino_Posting *self);
KINO_METHOD("Kino_Post_Destroy");

KINO_END_CLASS

#endif /* H_KINO_POSTING */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

