#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Posting/ScorePosting.h"
#include "KinoSearch/Analysis/Token.h"
#include "KinoSearch/Analysis/Inversion.h"
#include "KinoSearch/Index/PostingList.h"
#include "KinoSearch/Index/PostingPool.h"
#include "KinoSearch/Posting/RawPosting.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Search/Compiler.h"
#include "KinoSearch/Search/Matcher.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Util/MemoryPool.h"

#define FIELD_BOOST_LEN  1
#define FREQ_MAX_LEN     C32_MAX_BYTES
#define MAX_RAW_POSTING_LEN(_text_len, _freq) \
        (              sizeof(RawPosting) \
                     + _text_len                /* term text content */ \
                     + FIELD_BOOST_LEN          /* field boost byte */ \
                     + FREQ_MAX_LEN             /* freq c32 */ \
                     + (C32_MAX_BYTES * _freq)  /* positions deltas */ \
        )

ScorePosting*
ScorePost_new(Similarity *sim)
{
    ScorePosting *self = (ScorePosting*)VTable_Make_Obj(SCOREPOSTING);
    return ScorePost_init(self, sim);
}

ScorePosting*
ScorePost_init(ScorePosting *self, Similarity *sim)
{
    MatchPost_init((MatchPosting*)self, sim);
    self->freq        = 0;
    self->weight      = 0.0;
    self->prox        = NULL;
    self->prox_cap    = 0;
    return self;
}

ScorePosting*
ScorePost_clone(ScorePosting *self)
{
    ScorePosting *evil_twin = (ScorePosting*)VTable_Make_Obj(self->vtable);
    ScorePost_init(evil_twin, self->sim);

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

void
ScorePost_destroy(ScorePosting *self)
{
    FREEMEM(self->prox);
    SUPER_DESTROY(self, SCOREPOSTING);
}

void
ScorePost_add_inversion_to_pool(ScorePosting *self, PostingPool *post_pool, 
                                Inversion *inversion, FieldType *type, 
                                i32_t doc_id, float doc_boost, 
                                float length_norm)
{
    MemoryPool  *mem_pool = post_pool->mem_pool;
    Similarity  *sim = self->sim;
    float        field_boost = doc_boost * type->boost * length_norm;
    const u8_t   field_boost_byte  = Sim_Encode_Norm(sim, field_boost);
    Token      **tokens;
    u32_t        freq;

    Inversion_Reset(inversion);
    while ( (tokens = Inversion_Next_Cluster(inversion, &freq)) != NULL ) {
        Token   *token          = *tokens;
        u32_t    raw_post_bytes = MAX_RAW_POSTING_LEN(token->len, freq);
        RawPosting *raw_posting = RawPost_new(
            MemPool_Grab(mem_pool, raw_post_bytes), doc_id, freq,
            token->text, token->len
        );
        char *const start = raw_posting->blob + token->len;
        char *dest        = start;
        u32_t last_prox   = 0;
        u32_t i;

        /* Field_boost. */
        *((u8_t*)dest) = field_boost_byte;
        dest++;

        /* Positions. */
        for (i = 0; i < freq; i++) {
            Token *const t = tokens[i];
            const u32_t prox_delta = t->pos - last_prox;
            NumUtil_encode_c32(prox_delta, &dest);
            last_prox = t->pos; 
        }

        /* Resize raw posting memory allocation. */
        raw_posting->aux_len = dest - start;
        raw_post_bytes = dest - (char*)raw_posting;
        MemPool_Resize(mem_pool, raw_posting, raw_post_bytes);
        PostPool_Add_Elem(post_pool, (Obj*)raw_posting);
    }
}

void
ScorePost_reset(ScorePosting *self)
{
    self->doc_id   = 0;
    self->freq     = 0;
    self->weight   = 0.0;
}

void
ScorePost_read_record(ScorePosting *self, InStream *instream)
{
    u32_t  num_prox;
    u32_t  position = 0; 
    u32_t *positions;
    const  size_t max_start_bytes = (C32_MAX_BYTES * 2) + 1;
    char  *buf = InStream_Buf(instream, max_start_bytes);
    const u32_t doc_code = NumUtil_decode_c32(&buf);
    const u32_t doc_delta = doc_code >> 1;

    /* Apply delta doc and retrieve freq. */
    self->doc_id   += doc_delta;
    if (doc_code & 1) 
        self->freq = 1;
    else
        self->freq = NumUtil_decode_c32(&buf);

    /* Decode boost/norm byte. */
    self->weight = self->sim->norm_decoder[ *(u8_t*)buf ];
    buf++;

    /* Read positions. */
    num_prox = self->freq;
    if (num_prox > self->prox_cap) {
        self->prox = REALLOCATE(self->prox, num_prox, u32_t);
        self->prox_cap = num_prox;
    }
    positions = self->prox;

    InStream_Advance_Buf(instream, buf);
    buf = InStream_Buf(instream, num_prox * C32_MAX_BYTES);
    while (num_prox--) {
        position += NumUtil_decode_c32(&buf);
        *positions++ = position;
    }

    InStream_Advance_Buf(instream, buf);
}

RawPosting*
ScorePost_read_raw(ScorePosting *self, InStream *instream, i32_t last_doc_id,
                   CharBuf *term_text, MemoryPool *mem_pool)
{
    char *const  text_buf         = (char*)CB_Get_Ptr8(term_text);
    const size_t text_size        = CB_Get_Size(term_text);
    const u32_t  doc_code         = InStream_Read_C32(instream);
    const u32_t  delta_doc        = doc_code >> 1;
    const i32_t  doc_id           = last_doc_id + delta_doc;
    const u32_t  freq             = (doc_code & 1) 
                                       ? 1 
                                       : InStream_Read_C32(instream);
    size_t raw_post_bytes         = MAX_RAW_POSTING_LEN(text_size, freq);
    void *const allocation        = MemPool_Grab(mem_pool, raw_post_bytes);
    RawPosting *const raw_posting = RawPost_new(allocation, doc_id, freq,
        text_buf, text_size);
    u32_t  num_prox   = freq;
    char *const start = raw_posting->blob + text_size;
    char *      dest  = start;
    UNUSED_VAR(self);

    /* Field_boost. */
    *((u8_t*)dest) = InStream_Read_U8(instream);
    dest++;

    /* Read positions. */
    while (num_prox--) {
        dest += InStream_Read_Raw_C64(instream, dest);
    }

    /* Resize raw posting memory allocation. */
    raw_posting->aux_len = dest - start;
    raw_post_bytes       = dest - (char*)raw_posting;
    MemPool_Resize(mem_pool, raw_posting, raw_post_bytes);

    return raw_posting;
}

ScorePostingScorer*
ScorePost_make_matcher(ScorePosting *self, Similarity *sim, 
                       PostingList *plist, Compiler *compiler,
                       bool_t need_score)
{
    ScorePostingScorer *matcher
        = (ScorePostingScorer*)VTable_Make_Obj(SCOREPOSTINGSCORER);
    UNUSED_VAR(self);
    UNUSED_VAR(need_score);
    return ScorePostScorer_init(matcher, sim, plist, compiler);
}

ScorePostingScorer*
ScorePostScorer_init(ScorePostingScorer *self, Similarity *sim, 
                     PostingList *plist, Compiler *compiler)
{
    u32_t i;

    /* Init. */
    TermScorer_init((TermScorer*)self, sim, plist, compiler);

    /* Fill score cache. */
    self->score_cache = MALLOCATE(TERMSCORER_SCORE_CACHE_SIZE, float);
    for (i = 0; i < TERMSCORER_SCORE_CACHE_SIZE; i++) {
        self->score_cache[i] = Sim_TF(sim, (float)i) * self->weight;
    }

    return self;
}   

float
ScorePostScorer_score(ScorePostingScorer* self) 
{
    ScorePosting *const posting = (ScorePosting*)self->posting;
    const u32_t  freq           = posting->freq;
    
    /* Calculate initial score based on frequency of term. */
    float score = (freq < TERMSCORER_SCORE_CACHE_SIZE) 
        ? self->score_cache[freq] /* cache hit */
        : Sim_TF(self->sim, (float)freq) * self->weight;

    /* Factor in field-length normalization and doc/field/prox boost. */
    score *= posting->weight;

    return score;
}

void
ScorePostScorer_destroy(ScorePostingScorer *self)
{
    FREEMEM(self->score_cache);
    SUPER_DESTROY(self, SCOREPOSTINGSCORER);
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

