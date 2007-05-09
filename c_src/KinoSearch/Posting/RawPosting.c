#include "KinoSearch/Util/ToolSet.h"

#include <string.h>

#define KINO_WANT_RAWPOSTING_VTABLE
#include "KinoSearch/Posting/RawPosting.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Util/StringHelper.h"

RawPosting KINO_RAWPOSTING_BLANK = { 
    &RAWPOSTING, 
    1, 
    NULL,                  /* sim */
    NULL,                  /* next */
    0,                     /* doc_num */
    1,                     /* freq */
    0,                     /* content_len */
    0,                     /* aux_len */
    { '\0' }               /* blob */
};


RawPosting*
RawPost_new(void *pre_allocated_memory, u32_t doc_num, u32_t freq, 
            char *term_text, size_t term_text_len)
{
    RawPosting *self    = (RawPosting*)pre_allocated_memory;
    self->_             = &RAWPOSTING;
    self->refcount      = 1;
    self->doc_num       = doc_num;
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
    CONFESS("Illegal attempt to destroy RawPosting object");
}

void
RawPost_write_record(RawPosting *self, OutStream *outstream, 
                     u32_t last_doc_num)
{
    const u32_t delta_doc = self->doc_num - last_doc_num;
    char  *const aux_content = self->blob + self->content_len;
    if (self->freq == 1) {
        const u32_t doc_code = (delta_doc << 1) | 1;
        OutStream_Write_VInt(outstream, doc_code);
    }
    else {
        const u32_t doc_code = delta_doc << 1;
        OutStream_Write_VInt(outstream, doc_code);
        OutStream_Write_VInt(outstream, self->freq);
    }
    OutStream_Write_Bytes(outstream, aux_content, self->aux_len);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

