/**
 * @class KinoSearch::Posting::ScorePosting  ScorePosting.r
 */
#ifndef H_KINO_SCOREPOSTING
#define H_KINO_SCOREPOSTING 1

#include "KinoSearch/Posting/MatchPosting.r"

struct kino_ScorePostingScorer;

typedef struct kino_ScorePosting kino_ScorePosting;
typedef struct KINO_SCOREPOSTING_VTABLE KINO_SCOREPOSTING_VTABLE;

KINO_CLASS("KinoSearch::Posting::ScorePosting", "ScorePost", 
    "KinoSearch::Posting::MatchPosting");

struct kino_ScorePosting {
    KINO_SCOREPOSTING_VTABLE *_;
    KINO_MATCHPOSTING_MEMBER_VARS;
    chy_u32_t               freq;
    float                   impact;
    chy_u32_t              *prox;
    chy_u32_t               prox_cap;
};

/* Constructor.
 */
kino_ScorePosting*
kino_ScorePost_new(struct kino_Similarity *sim);

void
kino_ScorePost_destroy(kino_ScorePosting *self);
KINO_METHOD("Kino_ScorePost_Destroy");

kino_ScorePosting*
kino_ScorePost_clone(kino_ScorePosting *self);
KINO_METHOD("Kino_ScorePost_Clone");

kino_ScorePosting*
kino_ScorePost_dupe(kino_ScorePosting *self, struct kino_Similarity *sim);
KINO_METHOD("Kino_ScorePost_Dupe");

void
kino_ScorePost_read_record(kino_ScorePosting *self, 
                           struct kino_InStream *instream);
KINO_METHOD("Kino_ScorePost_Read_Record");

struct kino_RawPosting*
kino_ScorePost_read_raw(kino_ScorePosting *self, 
                        struct kino_InStream *instream,
                        chy_u32_t last_doc_num, 
                        struct kino_ByteBuf *term_text, 
                        struct kino_MemoryPool *mem_pool);
KINO_METHOD("Kino_ScorePost_Read_Raw");

void
kino_ScorePost_add_batch_to_pool(kino_ScorePosting *self, 
                                 struct kino_PostingPool *post_pool, 
                                 struct kino_TokenBatch *batch, 
                                 struct kino_FieldSpec *fspec, 
                                 chy_u32_t doc_num, float doc_boost, 
                                 float length_norm);
KINO_METHOD("Kino_ScorePost_Add_Batch_To_Pool");

void
kino_ScorePost_reset(kino_ScorePosting *self, chy_u32_t doc_num);
KINO_METHOD("Kino_ScorePost_Reset");

struct kino_ScorePostingScorer*
kino_ScorePost_make_scorer(kino_ScorePosting *self, 
                           struct kino_Similarity *sim,
                           struct kino_PostingList *plist, 
                           void *weight, float weight_val);
KINO_METHOD("Kino_ScorePost_Make_Scorer");

KINO_END_CLASS

#endif /* H_KINO_SCOREPOSTING */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

