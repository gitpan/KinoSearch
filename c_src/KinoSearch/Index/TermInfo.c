#include "KinoSearch/Util/ToolSet.h"

#include <stdio.h>

#define KINO_WANT_TERMINFO_VTABLE
#include "KinoSearch/Index/TermInfo.r"

#include "KinoSearch/Util/StringHelper.h"


TermInfo*
TInfo_new(i32_t doc_freq,
          u64_t post_filepos,
          u64_t skip_filepos,
          u64_t index_filepos)
{
    CREATE(self, TermInfo, TERMINFO);

    self->doc_freq      = doc_freq;
    self->post_filepos  = post_filepos;
    self->skip_filepos  = skip_filepos;
    self->index_filepos = index_filepos;

    return self;
}

TermInfo*
TInfo_clone(TermInfo *self) 
{
    TermInfo* new_tinfo = MALLOCATE(1, TermInfo);
    *new_tinfo = *self;
    new_tinfo->refcount = 1;
    return new_tinfo;
}

/* TODO: this should probably be some sort of Dump variant rather than
 * To_String.
 */
ByteBuf*
TInfo_to_string(TermInfo *self)
{
    ByteBuf *string = BB_new(150);

    string->len = sprintf(string->ptr, 
        "doc freq:      %ld\n"
        "post filepos:  %" I64P "\n"
        "skip filepos:  %" I64P "\n" 
        "index filepos: %" I64P,
        (long)self->doc_freq, self->post_filepos,
        self->skip_filepos, self->index_filepos);

    return string;
}

void
TInfo_copy(TermInfo *self, const TermInfo *other) 
{
    self->doc_freq      = other->doc_freq;
    self->post_filepos  = other->post_filepos;
    self->skip_filepos  = other->skip_filepos;
    self->index_filepos = other->index_filepos;
}

void
TInfo_reset(TermInfo *self) 
{
    self->doc_freq      = 0;
    self->post_filepos  = 0;
    self->skip_filepos  = 0;
    self->index_filepos = 0;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

