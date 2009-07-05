#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Posting/MatchPosting.h"
#include "KinoSearch/Analysis/Inversion.h"
#include "KinoSearch/Analysis/Token.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/PostingList.h"
#include "KinoSearch/Index/PostingPool.h"
#include "KinoSearch/Posting/RawPosting.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Search/Compiler.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Util/MemoryPool.h"

#define MAX_RAW_POSTING_LEN(_text_len) \
        (              sizeof(RawPosting) \
                     + _text_len + 1            /* term text content */ \
        )

MatchPosting*
MatchPost_new(Similarity *sim)
{
    MatchPosting *self = (MatchPosting*)VTable_Make_Obj(&MATCHPOSTING);
    return MatchPost_init(self, sim);
}

MatchPosting*
MatchPost_init(MatchPosting *self, Similarity *sim)
{
    self->sim = (Similarity*)INCREF(sim);
    return (MatchPosting*)Post_init((Posting*)self);
}

void
MatchPost_destroy(MatchPosting *self)
{
    DECREF(self->sim);
    FREE_OBJ(self);
}

MatchPosting*
MatchPost_clone(MatchPosting *self)
{
    MatchPosting *evil_twin = (MatchPosting*)VTable_Make_Obj(self->vtable);
    return MatchPost_init(evil_twin, self->sim);
}

void
MatchPost_reset(MatchPosting *self, i32_t doc_id)
{
    self->doc_id   = doc_id;
}

void
MatchPost_read_record(MatchPosting *self, InStream *instream)
{
    const u32_t doc_code = InStream_Read_C32(instream);
    const u32_t doc_delta = doc_code >> 1;

    /* Apply delta doc and retrieve freq. */
    self->doc_id   += doc_delta;
    if (doc_code & 1) 
        self->freq = 1;
    else
        self->freq = InStream_Read_C32(instream);
}

RawPosting*
MatchPost_read_raw(MatchPosting *self, InStream *instream, i32_t last_doc_id,
                   CharBuf *term_text, MemoryPool *mem_pool)
{
    const size_t text_size        = CB_Get_Size(term_text);
    const u32_t  doc_code         = InStream_Read_C32(instream);
    const u32_t  delta_doc        = doc_code >> 1;
    const i32_t  doc_id           = last_doc_id + delta_doc;
    const u32_t  freq             = (doc_code & 1) 
                                       ? 1 
                                       : InStream_Read_C32(instream);
    size_t raw_post_bytes         = MAX_RAW_POSTING_LEN(text_size);
    void *const allocation        = MemPool_Grab(mem_pool, raw_post_bytes);
    UNUSED_VAR(self);

    return RawPost_new(allocation, doc_id, freq, term_text->ptr, text_size);
}

void
MatchPost_add_inversion_to_pool(MatchPosting *self, PostingPool *post_pool, 
                                Inversion *inversion, FieldType *type, 
                                i32_t doc_id, float doc_boost, 
                                float length_norm)
{
    MemoryPool  *mem_pool = post_pool->mem_pool;
    Token      **tokens;
    u32_t        freq;

    UNUSED_VAR(self);
    UNUSED_VAR(type);
    UNUSED_VAR(doc_boost);
    UNUSED_VAR(length_norm);

    Inversion_Reset(inversion);
    while ( (tokens = Inversion_Next_Cluster(inversion, &freq)) != NULL ) {
        Token   *token          = *tokens;
        u32_t    raw_post_bytes = MAX_RAW_POSTING_LEN(token->len);
        RawPosting *raw_posting = RawPost_new(
            MemPool_Grab(mem_pool, raw_post_bytes), doc_id, freq,
            token->text, token->len
        );
        PostPool_Add_Elem(post_pool, (Obj*)raw_posting);
    }
}

MatchPostingScorer*
MatchPost_make_matcher(MatchPosting *self, Similarity *sim, 
                       PostingList *plist, Compiler *compiler,
                       bool_t need_score)
{
    MatchPostingScorer *matcher 
        = (MatchPostingScorer*)VTable_Make_Obj(&MATCHPOSTINGSCORER);
    UNUSED_VAR(self);
    UNUSED_VAR(need_score);
    return MatchPostScorer_init(matcher, sim, plist, compiler);
}

MatchPostingScorer*
MatchPostScorer_init(MatchPostingScorer *self, Similarity *sim,
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
MatchPostScorer_score(MatchPostingScorer* self) 
{
    MatchPosting *const posting = (MatchPosting*)self->posting;
    const u32_t  freq           = posting->freq;
    float score = (freq < TERMSCORER_SCORE_CACHE_SIZE) 
        ? self->score_cache[freq] /* cache hit */
        : Sim_TF(self->sim, (float)freq) * self->weight;
    return score;
}

void
MatchPostScorer_destroy(MatchPostingScorer *self)
{
    FREEMEM(self->score_cache);
    SUPER_DESTROY(self, MATCHPOSTINGSCORER);
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

