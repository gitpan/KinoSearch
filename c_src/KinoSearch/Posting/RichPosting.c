#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_RICHPOSTING_VTABLE
#include "KinoSearch/Posting/RichPosting.r"

#include "KinoSearch/Analysis/Token.r"
#include "KinoSearch/Analysis/TokenBatch.r"
#include "KinoSearch/Index/PostingPool.r"
#include "KinoSearch/Posting/RawPosting.r"
#include "KinoSearch/Posting/RichPostingScorer.r"
#include "KinoSearch/Schema/FieldSpec.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Util/MemoryPool.r"

#define FREQ_MAX_LEN     VINT_MAX_BYTES
#define MAX_RAW_POSTING_LEN(_text_len, _freq) \
        (              sizeof(RawPosting) \
                     + _text_len                /* term text content */ \
                     + FREQ_MAX_LEN             /* freq vint */ \
                     + (VINT_MAX_BYTES * _freq) /* positions deltas */ \
                     + _freq                    /* per-pos boost byte */ \
        )

RichPosting*
RichPost_new(Similarity *sim)
{
    CREATE(self, RichPosting, RICHPOSTING);
    
    /* init */
    self->next            = NULL;
    self->doc_num         = DOC_NUM_SENTINEL;
    self->freq            = 0;
    self->impact          = 0.0;
    self->prox            = NULL;
    self->prox_cap        = 0;
    self->prox_boosts     = NULL;

    /* assign */
    REFCOUNT_INC(sim);
    self->sim             = sim;

    return self;
}

void
RichPost_destroy(RichPosting *self)
{
    REFCOUNT_DEC(self->sim);
    free(self->prox);
    free(self->prox_boosts);
    free(self);
}

RichPosting*
RichPost_clone(RichPosting *self)
{
    RichPosting *evil_twin = RichPost_new(self->sim);
    *evil_twin = *self;

    evil_twin->next = NULL;

    if (self->freq) {
        evil_twin->prox_cap = evil_twin->freq;
        evil_twin->prox = MALLOCATE(evil_twin->freq, u32_t);
        evil_twin->prox_boosts = MALLOCATE(evil_twin->freq, float);
        memcpy(evil_twin->prox, self->prox, self->freq * sizeof(u32_t));
        memcpy(evil_twin->prox_boosts, self->prox_boosts, 
            self->freq * sizeof(float));
    }
    else {
        evil_twin->prox        = NULL;
        evil_twin->prox_boosts = NULL;
    }

    return evil_twin;
}

RichPosting*
RichPost_dupe(RichPosting *self, Similarity *sim)
{
    RichPosting *evil_twin = (RichPosting*)RichPost_Clone(self);
    REFCOUNT_DEC(evil_twin->sim);
    REFCOUNT_INC(sim);
    evil_twin->sim = sim;
    return evil_twin;
}

void
RichPost_read_record(RichPosting *self, InStream *instream)
{
    float *const norm_decoder = self->sim->norm_decoder;
    u32_t  doc_code;
    u32_t  num_prox = 0;
    u32_t  position = 0; 
    u32_t *positions;
    float *prox_boosts;
    float  aggregate_impact = 0.0;

    /* decode delta doc */
    doc_code = InStream_Read_VInt(instream);
    self->doc_num  += doc_code >> 1;

    /* if the stored num was odd, the freq is 1 */ 
    if (doc_code & 1) {
        self->freq = 1;
    }
    /* otherwise, freq was stored as a VInt. */
    else {
        self->freq = InStream_Read_VInt(instream);
    } 

    /* read positions, aggregate per-position boost byte into impact */
    num_prox = self->freq;
    if (num_prox > self->prox_cap) {
        self->prox        = REALLOCATE(self->prox, num_prox, u32_t);
        self->prox_boosts = REALLOCATE(self->prox_boosts, num_prox, float);
    }
    positions   = self->prox;
    prox_boosts = self->prox_boosts;

    while (num_prox--) {
        position += InStream_Read_VInt(instream);
        *positions++ = position;
        *prox_boosts = norm_decoder[ (u8_t)InStream_Read_Byte(instream) ];
        aggregate_impact += *prox_boosts;
        prox_boosts++;
    }
    self->impact = aggregate_impact / self->freq;
}

u32_t
RichPost_bulk_read(RichPosting *self, InStream *instream, ByteBuf *postings, 
                   u32_t num_wanted)
{
    u32_t num_got = 0;

    /* start with a clean slate */
    postings->len = 0;
    BB_GROW(postings, 1200);     /* try to avoid realloc */

    /* start with dummy posting */
    BB_Cat_Str(postings, (char*)&POST_DUMMY, sizeof(Posting));

    for ( ; num_got < num_wanted; num_got++) { 
        RichPost_read_record(self, instream);

        /* concat onto end of bytebuf */
        BB_Cat_Str(postings, (char*)self, sizeof(RichPosting));
        BB_Cat_Str(postings, (char*)self->prox, 
            (self->freq * sizeof(u32_t)) );
        BB_Cat_Str(postings, (char*)self->prox_boosts, 
            (self->freq * sizeof(float)) );
    }

    /* build linked list */
    if (num_got) {
        RichPosting *temp = NULL;
        char *limit = BBEND(postings);
        char *ptr = postings->ptr + sizeof(Posting);
        Posting *dummy = (Posting*)postings->ptr;
        dummy->next = (Posting*)ptr;
        while (ptr < limit) {
            temp = (RichPosting*)ptr;
            ptr += sizeof(RichPosting);           /* ff past main struct */
            temp->prox = (u32_t*)ptr;
            ptr += (temp->freq * sizeof(u32_t));   /* ff past positions */
            temp->prox_boosts = (float*)ptr;
            ptr += (temp->freq * sizeof(float));   /* ff past prox boosts */
            temp->next = (Posting*)ptr;
        }
        /* terminate linked list */
        temp->next = NULL;
    }

    return num_got;
}

void
RichPost_add_batch_to_pool(RichPosting *self, PostingPool *post_pool, 
                           TokenBatch *batch, FieldSpec *fspec, 
                           u32_t doc_num, float doc_boost, float length_norm)
{
    MemoryPool  *mem_pool = post_pool->mem_pool;
    Similarity  *sim = self->sim;
    float        field_boost = doc_boost * fspec->boost * length_norm;
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

        /* positions and boosts */
        for (i = 0; i < freq; i++) {
            Token *const t = tokens[i];
            const u32_t prox_delta = t->pos - last_prox;
            const float boost = field_boost * t->boost;

            ENCODE_VINT(prox_delta, dest);
            last_prox = t->pos; 

            *((u8_t*)dest) = Sim_Encode_Norm(sim, boost);
            dest++;
        }

        /* resize raw posting memory allocation */
        raw_posting->aux_len = dest - start;
        raw_post_bytes = dest - (char*)raw_posting;
        MemPool_Resize(mem_pool, raw_posting, raw_post_bytes);
        PostPool_Add_Posting(post_pool, raw_posting);
    }
}

RawPosting*
RichPost_read_raw(RichPosting *self, InStream *instream, u32_t last_doc_num, 
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

    /* read positions and per-position boosts */
    while (num_prox--) {
        dest += InStream_Read_Raw_VLong(instream, dest);
        *((u8_t*)dest) = (u8_t)InStream_Read_Byte(instream);
        dest++;
    }

    /* resize raw posting memory allocation */
    raw_posting->aux_len = dest - start;
    raw_post_bytes       = dest - (char*)raw_posting;
    MemPool_Resize(mem_pool, raw_posting, raw_post_bytes);

    return raw_posting;
}

RichPostingScorer*
RichPost_make_scorer(RichPosting *self, Similarity *sim, 
                     struct kino_PostingList *plist, 
                     void *weight, float weight_val)
{
    return RichPostScorer_new(sim, plist, weight, weight_val);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

