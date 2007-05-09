/**
 * @class KinoSearch::Posting::RichPosting  RichPosting.r
 */
#ifndef H_KINO_RICHPOSTING
#define H_KINO_RICHPOSTING 1

#include "KinoSearch/Posting/ScorePosting.r"

struct kino_RichPostingScorer;

typedef struct kino_RichPosting kino_RichPosting;
typedef struct KINO_RICHPOSTING_VTABLE KINO_RICHPOSTING_VTABLE;

KINO_CLASS("KinoSearch::Posting::RichPosting", "RichPost", 
    "KinoSearch::Posting::ScorePosting");

struct kino_RichPosting {
    KINO_RICHPOSTING_VTABLE *_;
    KINO_SCOREPOSTING_MEMBER_VARS;
    float            *prox_boosts;
};

/* Constructor.
 */
kino_RichPosting*
kino_RichPost_new(struct kino_Similarity *sim);

void
kino_RichPost_destroy(kino_RichPosting *self);
KINO_METHOD("Kino_RichPost_Destroy");

kino_RichPosting*
kino_RichPost_clone(kino_RichPosting *self);
KINO_METHOD("Kino_RichPost_Clone");

kino_RichPosting*
kino_RichPost_dupe(kino_RichPosting *self, struct kino_Similarity *sim);
KINO_METHOD("Kino_RichPost_Dupe");

void
kino_RichPost_read_record(kino_RichPosting *self, 
                          struct kino_InStream *instream);
KINO_METHOD("Kino_RichPost_Read_Record");

chy_u32_t
kino_RichPost_bulk_read(kino_RichPosting *self, 
                        struct kino_InStream *instream, 
                        struct kino_ByteBuf *postings, chy_u32_t num_wanted);
KINO_METHOD("Kino_RichPost_Bulk_Read");

struct kino_RawPosting*
kino_RichPost_read_raw(kino_RichPosting *self, 
                       struct kino_InStream *instream,
                       chy_u32_t last_doc_num, 
                       struct kino_ByteBuf *term_text, 
                       struct kino_MemoryPool *mem_pool);
KINO_METHOD("Kino_RichPost_Read_Raw");

void
kino_RichPost_add_batch_to_pool(kino_RichPosting *self, 
                                struct kino_PostingPool *post_pool, 
                                struct kino_TokenBatch *batch, 
                                struct kino_FieldSpec *fspec, 
                                chy_u32_t doc_num, float doc_boost, 
                                float length_norm);
KINO_METHOD("Kino_RichPost_Add_Batch_To_Pool");

struct kino_RichPostingScorer*
kino_RichPost_make_scorer(kino_RichPosting *self, 
                          struct kino_Similarity *sim,
                          struct kino_PostingList *plist, 
                          void *weight, float weight_val);
KINO_METHOD("Kino_RichPost_Make_Scorer");

KINO_END_CLASS

#endif /* H_KINO_RICHPOSTING */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

