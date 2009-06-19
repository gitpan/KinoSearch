#include "KinoSearch/Util/ToolSet.h"

#include <string.h>

#include "KinoSearch/Posting/RawPosting.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/StringHelper.h"

RawPosting RAWPOSTING_BLANK = { 
    (VTable*)&RAWPOSTING, 
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
    self->vtable        = (VTable*)&RAWPOSTING;
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
    THROW("Illegal attempt to destroy RawPosting object");
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

void
RawPost_write_record(RawPosting *self, OutStream *outstream, 
                     i32_t last_doc_id)
{
    const u32_t delta_doc = self->doc_id - last_doc_id;
    char  *const aux_content = self->blob + self->content_len;
    if (self->freq == 1) {
        const u32_t doc_code = (delta_doc << 1) | 1;
        OutStream_Write_C32(outstream, doc_code);
    }
    else {
        const u32_t doc_code = delta_doc << 1;
        OutStream_Write_C32(outstream, doc_code);
        OutStream_Write_C32(outstream, self->freq);
    }
    OutStream_Write_Bytes(outstream, aux_content, self->aux_len);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

