#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCOREPOSTING_VTABLE
#include "KinoSearch/Posting/ScorePosting.r"

#include "KinoSearch/Analysis/Token.r"
#include "KinoSearch/Analysis/TokenBatch.r"
#include "KinoSearch/Index/PostingPool.r"
#include "KinoSearch/Posting/ScorePostingScorer.r"
#include "KinoSearch/Posting/RawPosting.r"
#include "KinoSearch/FieldSpec.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Util/MemoryPool.r"

#define FIELD_BOOST_LEN  1
#define FREQ_MAX_LEN     VINT_MAX_BYTES
#define MAX_RAW_POSTING_LEN(_text_len, _freq) \
        (              sizeof(RawPosting) \
                     + _text_len                /* term text content */ \
                     + FIELD_BOOST_LEN          /* field boost byte */ \
                     + FREQ_MAX_LEN             /* freq vint */ \
                     + (VINT_MAX_BYTES * _freq) /* positions deltas */ \
        )

ScorePosting*
ScorePost_new(Similarity *sim)
{
    CREATE(self, ScorePosting, SCOREPOSTING);

    /* init */
    self->doc_num     = DOC_NUM_SENTINEL;
    self->freq        = 0;
    self->impact      = 0.0;
    self->prox        = NULL;
    self->prox_cap    = 0;

    /* assign */
    self->sim         = REFCOUNT_INC(sim);

    return self;
}

ScorePosting*
ScorePost_clone(ScorePosting *self)
{
    ScorePosting *evil_twin = ScorePost_new(self->sim);
    *evil_twin = *self;

    if (self->freq) {
        evil_twin->prox_cap = evil_twin->freq;
        evil_twin->prox = MALLOCATE(evil_twin->freq, u32_t);
        memcpy(evil_twin->prox, self->prox, self->freq * sizeof(u32_t));
    }
    else {
        evil_twin->prox = NULL;
    }

    return evil_twin;
}

ScorePosting*
ScorePost_dupe(ScorePosting *self, Similarity *sim)
{
    ScorePosting *evil_twin = (ScorePosting*)ScorePost_Clone(self);
    REFCOUNT_DEC(evil_twin->sim);
    evil_twin->sim = REFCOUNT_INC(sim);
    return evil_twin;
}

void
ScorePost_destroy(ScorePosting *self)
{
    REFCOUNT_DEC(self->sim);
    free(self->prox);
    free(self);
}

void
ScorePost_add_batch_to_pool(ScorePosting *self, PostingPool *post_pool, 
                            TokenBatch *batch, FieldSpec *fspec, 
                            u32_t doc_num, float doc_boost, float length_norm)
{
    MemoryPool  *mem_pool = post_pool->mem_pool;
    Similarity  *sim = self->sim;
    float        field_boost = doc_boost * fspec->boost * length_norm;
    const u8_t   field_boost_byte  = Sim_Encode_Norm(sim, field_boost);
    Token      **tokens;
    u32_t        freq;

    TokenBatch_Reset(batch);
    while ( (tokens = TokenBatch_Next_Cluster(batch, &freq)) != NULL ) {
        Token   *token          = *tokens;
        u32_t    raw_post_bytes = MAX_RAW_POSTING_LEN(token->len, freq);
        RawPosting *raw_posting = RawPost_new(
            MemPool_Grab(mem_pool, raw_post_bytes), doc_num, freq,
            token->text, token->len
        );
        char *const start = raw_posting->blob + token->len;
        char *dest        = start;
        u32_t last_prox   = 0;
        u32_t i;

        /* field_boost */
        *((u8_t*)dest) = field_boost_byte;
        dest++;

        /* positions */
        for (i = 0; i < freq; i++) {
            Token *const t = tokens[i];
            const u32_t prox_delta = t->pos - last_prox;
            ENCODE_VINT(prox_delta, dest);
            last_prox = t->pos; 
        }

        /* resize raw posting memory allocation */
        raw_posting->aux_len = dest - start;
        raw_post_bytes = dest - (char*)raw_posting;
        MemPool_Resize(mem_pool, raw_posting, raw_post_bytes);
        PostPool_Add_Posting(post_pool, raw_posting);
    }
}

void
ScorePost_reset(ScorePosting *self, u32_t doc_num)
{
    self->doc_num  = doc_num;
    self->freq     = 0;
    self->impact   = 0.0;
}

void
ScorePost_read_record(ScorePosting *self, InStream *instream)
{
    u32_t  num_prox;
    u32_t  position = 0; 
    u32_t *positions;
    const u32_t doc_code = InStream_Read_VInt(instream);
    const u32_t doc_delta = doc_code >> 1;

    /* apply delta doc and retrieve freq */
    self->doc_num  += doc_delta;
    if (doc_code & 1) 
        self->freq = 1;
    else
        self->freq = InStream_Read_VInt(instream);

    /* decode boost/norm byte */
    self->impact = self->sim->norm_decoder[ 
        (u8_t)InStream_Read_Byte(instream) ];
    
    /* read positions */
    num_prox = self->freq;
    if (num_prox > self->prox_cap) {
        self->prox = REALLOCATE(self->prox, num_prox, u32_t);
    }
    positions = self->prox;

    while (num_prox--) {
        position += InStream_Read_VInt(instream);
        *positions++ = position;
    }
}

RawPosting*
ScorePost_read_raw(ScorePosting *self, InStream *instream, u32_t last_doc_num,
                   ByteBuf *term_text, MemoryPool *mem_pool)
{
    const u32_t  doc_code         = InStream_Read_VInt(instream);
    const u32_t  delta_doc        = doc_code >> 1;
    const u32_t  doc_num          = last_doc_num + delta_doc;
    const u32_t  freq             = (doc_code & 1) 
                                       ? 1 
                                       : InStream_Read_VInt(instream);
    size_t raw_post_bytes         = MAX_RAW_POSTING_LEN(term_text->len, freq);
    void *const allocation        = MemPool_Grab(mem_pool, raw_post_bytes);
    RawPosting *const raw_posting = RawPost_new(allocation, doc_num, freq,
        term_text->ptr, term_text->len);
    u32_t  num_prox   = freq;
    char *const start = raw_posting->blob + term_text->len;
    char *      dest  = start;
    UNUSED_VAR(self);

    /* field_boost */
    *((u8_t*)dest) = (u8_t)InStream_Read_Byte(instream);
    dest++;

    /* read positions */
    while (num_prox--) {
        dest += InStream_Read_Raw_VLong(instream, dest);
    }

    /* resize raw posting memory allocation */
    raw_posting->aux_len = dest - start;
    raw_post_bytes       = dest - (char*)raw_posting;
    MemPool_Resize(mem_pool, raw_posting, raw_post_bytes);

    return raw_posting;
}

ScorePostingScorer*
ScorePost_make_scorer(ScorePosting *self, Similarity *sim, 
                      struct kino_PostingList *plist, 
                      void *weight, float weight_val)
{
    UNUSED_VAR(self);
    return ScorePostScorer_new(sim, plist, weight, weight_val);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

