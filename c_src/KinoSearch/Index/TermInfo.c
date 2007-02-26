#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TERMINFO_VTABLE
#include "KinoSearch/Index/TermInfo.r"


TermInfo*
TInfo_new(i32_t field_num,
          i32_t doc_freq,
          u64_t post_fileptr,
          i32_t skip_offset,
          u64_t index_fileptr)
{
    CREATE(self, TermInfo, TERMINFO);

    self->field_num     = field_num;
    self->doc_freq      = doc_freq;
    self->post_fileptr  = post_fileptr;
    self->skip_offset   = skip_offset;
    self->index_fileptr = index_fileptr;

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

void
TInfo_copy(TermInfo *self, TermInfo *other) 
{
    self->field_num     = other->field_num;
    self->doc_freq      = other->doc_freq;
    self->post_fileptr  = other->post_fileptr;
    self->skip_offset   = other->skip_offset;
    self->index_fileptr = other->index_fileptr;
}

void
TInfo_reset(TermInfo *self) 
{
    self->field_num     = -1;
    self->doc_freq      = 0;
    self->post_fileptr  = 0;
    self->skip_offset   = 0;
    self->index_fileptr = 0;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

