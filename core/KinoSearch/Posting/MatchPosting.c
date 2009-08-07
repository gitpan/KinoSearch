#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Posting/MatchPosting.h"
#include "KinoSearch/Analysis/Inversion.h"
#include "KinoSearch/Analysis/Token.h"
#include "KinoSearch/Architecture.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/PostingList.h"
#include "KinoSearch/Index/PostingPool.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Posting/RawPosting.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Search/Compiler.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/MemoryPool.h"

#define MAX_RAW_POSTING_LEN(_text_len) \
        (              sizeof(RawPosting) \
                     + _text_len + 1            /* term text content */ \
        )

MatchPosting*
MatchPost_new(Similarity *sim)
{
    MatchPosting *self = (MatchPosting*)VTable_Make_Obj(MATCHPOSTING);
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
MatchPost_reset(MatchPosting *self)
{
    self->doc_id = 0;
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
        = (MatchPostingScorer*)VTable_Make_Obj(MATCHPOSTINGSCORER);
    UNUSED_VAR(self);
    UNUSED_VAR(need_score);
    return MatchPostScorer_init(matcher, sim, plist, compiler);
}

MatchPostingStreamer*
MatchPost_make_streamer(MatchPosting *self, DataWriter *writer, 
                        i32_t field_num)
{
    UNUSED_VAR(self);
    return MatchPostStreamer_new(writer, field_num);
}

/***************************************************************************/

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

/***************************************************************************/

MatchPostingStreamer*
MatchPostStreamer_new(DataWriter *writer, i32_t field_num)
{
    MatchPostingStreamer *self 
        = (MatchPostingStreamer*)VTable_Make_Obj(MATCHPOSTINGSTREAMER);
    return MatchPostStreamer_init(self, writer, field_num);
}

MatchPostingStreamer*
MatchPostStreamer_init(MatchPostingStreamer *self, DataWriter *writer, 
                       i32_t field_num)
{
    Folder   *folder   = DataWriter_Get_Folder(writer);
    Segment  *segment  = DataWriter_Get_Segment(writer);
    Snapshot *snapshot = DataWriter_Get_Snapshot(writer);
    CharBuf *filename 
        = CB_newf("%o/postings-%i32.dat", Seg_Get_Name(segment), field_num);
    PostStreamer_init((PostingStreamer*)self, writer, field_num);
    Snapshot_Add_Entry(snapshot, filename);
    self->outstream = Folder_Open_Out(folder, filename);
    if (!self->outstream) { THROW(ERR, "Failed to open %o", filename); }
    DECREF(filename);
    return self;
}

void
MatchPostStreamer_destroy(MatchPostingStreamer *self)
{
    DECREF(self->outstream);
    SUPER_DESTROY(self, MATCHPOSTINGSTREAMER);
}

void
MatchPostStreamer_write_posting(MatchPostingStreamer *self, 
                                RawPosting *posting)
{
    OutStream *const outstream   = self->outstream;
    const i32_t      doc_id      = posting->doc_id;
    const u32_t      delta_doc   = doc_id - self->last_doc_id;
    char  *const     aux_content = posting->blob + posting->content_len;
    if (posting->freq == 1) {
        const u32_t doc_code = (delta_doc << 1) | 1;
        OutStream_Write_C32(outstream, doc_code);
    }
    else {
        const u32_t doc_code = delta_doc << 1;
        OutStream_Write_C32(outstream, doc_code);
        OutStream_Write_C32(outstream, posting->freq);
    }
    OutStream_Write_Bytes(outstream, aux_content, posting->aux_len);
    self->last_doc_id = doc_id;
}

void
MatchPostStreamer_start_term(MatchPostingStreamer *self, TermInfo *tinfo)
{
    self->last_doc_id   = 0;
    tinfo->post_filepos = OutStream_Tell(self->outstream);
}

void
MatchPostStreamer_update_skip_info(MatchPostingStreamer *self, 
                                   TermInfo *tinfo)
{
    tinfo->post_filepos = OutStream_Tell(self->outstream);
}

/***************************************************************************/

MatchTermInfoStepper*
MatchTInfoStepper_new(Schema *schema)
{
    MatchTermInfoStepper *self 
        = (MatchTermInfoStepper*)VTable_Make_Obj(MATCHTERMINFOSTEPPER);
    return MatchTInfoStepper_init(self, schema);
}

MatchTermInfoStepper*
MatchTInfoStepper_init(MatchTermInfoStepper *self, Schema *schema)
{
    Architecture *arch = Schema_Get_Architecture(schema);
    TermStepper_init((TermStepper*)self);
    self->skip_interval = Arch_Skip_Interval(arch);
    self->value = (Obj*)TInfo_new(0);
    return self;
}

void
MatchTInfoStepper_reset(MatchTermInfoStepper *self)
{
    TInfo_Reset(self->value);
}

void
MatchTInfoStepper_write_key_frame(MatchTermInfoStepper *self, 
                                  OutStream *outstream, Obj *value)
{
    TermInfo *tinfo = (TermInfo*)ASSERT_IS_A(value, TERMINFO);

    /* Write doc_freq. */
    OutStream_Write_C32(outstream, tinfo->doc_freq);

    /* Write postings file pointer. */
    OutStream_Write_C64(outstream, tinfo->post_filepos);

    /* Write skip file pointer (maybe). */
    if (tinfo->doc_freq >= self->skip_interval) {
        OutStream_Write_C64(outstream, tinfo->skip_filepos);
    }

    TInfo_Mimic(self->value, (Obj*)tinfo);
}

void
MatchTInfoStepper_write_delta(MatchTermInfoStepper *self, 
                              OutStream *outstream, Obj *value)
{
    TermInfo *tinfo      = (TermInfo*)ASSERT_IS_A(value, TERMINFO);
    TermInfo *last_tinfo = (TermInfo*)self->value;
    i64_t     post_delta = tinfo->post_filepos - last_tinfo->post_filepos;

    /* Write doc_freq. */
    OutStream_Write_C32(outstream, tinfo->doc_freq);

    /* Write postings file pointer delta. */
    OutStream_Write_C64(outstream, post_delta);

    /* Write skip file pointer (maybe). */
    if (tinfo->doc_freq >= self->skip_interval) {
        OutStream_Write_C64(outstream, tinfo->skip_filepos);
    }

    TInfo_Mimic(self->value, (Obj*)tinfo);
}

void
MatchTInfoStepper_read_key_frame(MatchTermInfoStepper *self, 
                                 InStream *instream)
{ 
    TermInfo *const tinfo = (TermInfo*)self->value;

    /* Read doc freq. */
    tinfo->doc_freq = InStream_Read_C32(instream);

    /* Read postings file pointer. */
    tinfo->post_filepos = InStream_Read_C64(instream);

    /* Maybe read skip pointer. */
    if (tinfo->doc_freq >= self->skip_interval) {
        tinfo->skip_filepos = InStream_Read_C64(instream);
    }
    else {
        tinfo->skip_filepos = 0;
    }
}

void
MatchTInfoStepper_read_delta(MatchTermInfoStepper *self, InStream *instream)
{ 
    TermInfo *const tinfo = (TermInfo*)self->value;

    /* Read doc freq. */
    tinfo->doc_freq = InStream_Read_C32(instream);

    /* Adjust postings file pointer. */
    tinfo->post_filepos += InStream_Read_C64(instream);

    /* Maybe read skip pointer. */
    if (tinfo->doc_freq >= self->skip_interval) {
        tinfo->skip_filepos = InStream_Read_C64(instream);
    }
    else {
        tinfo->skip_filepos = 0;
    }
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
