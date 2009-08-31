#define C_KINO_RAWPOSTING
#define C_KINO_RAWPOSTINGSTREAMER
#define C_KINO_TERMINFO
#include "KinoSearch/Util/ToolSet.h"

#include <string.h>

#include "KinoSearch/Posting/RawPosting.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/StringHelper.h"

RawPosting RAWPOSTING_BLANK = { 
    KINO_RAWPOSTING, 
    {1},                   /* ref.count */
    0,                     /* doc_id */
    1,                     /* freq */
    0,                     /* content_len */
    0,                     /* aux_len */
    { '\0' }               /* blob */
};


RawPosting*
RawPost_new(void *pre_allocated_memory, i32_t doc_id, u32_t freq, 
            char *term_text, size_t term_text_len)
{
    RawPosting *self    = (RawPosting*)pre_allocated_memory;
    self->vtable        = RAWPOSTING;
    self->ref.count     = 1; /* never used */
    self->doc_id        = doc_id;
    self->freq          = freq;
    self->content_len   = term_text_len;
    self->aux_len       = 0;
    memcpy(&self->blob, term_text, term_text_len);

    return self;
}

void
RawPost_destroy(RawPosting *self)
{
    UNUSED_VAR(self);
    THROW(ERR, "Illegal attempt to destroy RawPosting object");
}

u32_t
RawPost_get_refcount(RawPosting* self)
{
    UNUSED_VAR(self);
    return 1;
}

RawPosting*
RawPost_inc_refcount(RawPosting* self)
{
    return self;
}

u32_t
RawPost_dec_refcount(RawPosting* self)
{
    UNUSED_VAR(self);
    return 1;
}

/***************************************************************************/

RawPostingStreamer*
RawPostStreamer_new(DataWriter *writer, OutStream *outstream)
{
    RawPostingStreamer *self 
        = (RawPostingStreamer*)VTable_Make_Obj(RAWPOSTINGSTREAMER);
    return RawPostStreamer_init(self, writer, outstream);
}

RawPostingStreamer*
RawPostStreamer_init(RawPostingStreamer *self, DataWriter *writer, 
                     OutStream *outstream)
{
    const i32_t invalid_field_num = 0;
    PostStreamer_init((PostingStreamer*)self, writer, invalid_field_num);
    self->outstream = (OutStream*)INCREF(outstream);
    self->last_doc_id = 0;
    return self;
}

void
RawPostStreamer_start_term(RawPostingStreamer *self, TermInfo *tinfo)
{
    self->last_doc_id   = 0;
    tinfo->post_filepos = OutStream_Tell(self->outstream);
}

void
RawPostStreamer_update_skip_info(RawPostingStreamer *self, TermInfo *tinfo)
{
    tinfo->post_filepos = OutStream_Tell(self->outstream);
}

void
RawPostStreamer_destroy(RawPostingStreamer *self)
{
    DECREF(self->outstream);
    SUPER_DESTROY(self, RAWPOSTINGSTREAMER);
}

void
RawPostStreamer_write_posting(RawPostingStreamer *self, RawPosting *posting)
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

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

