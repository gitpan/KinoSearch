#include "KinoSearch/Util/ToolSet.h"

#include <stdio.h>

#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Util/StringHelper.h"

TermInfo*
TInfo_new(i32_t doc_freq,
          u64_t post_filepos,
          u64_t skip_filepos,
          u64_t lex_filepos)
{
    TermInfo *self = (TermInfo*)VTable_Make_Obj(&TERMINFO);
    return TInfo_init(self, doc_freq, post_filepos, skip_filepos,
        lex_filepos);
}

TermInfo*
TInfo_init(TermInfo *self,
           i32_t doc_freq,
           u64_t post_filepos,
           u64_t skip_filepos,
           u64_t lex_filepos)
{
    self->doc_freq      = doc_freq;
    self->post_filepos  = post_filepos;
    self->skip_filepos  = skip_filepos;
    self->lex_filepos   = lex_filepos;

    return self;
}

TermInfo*
TInfo_clone(TermInfo *self) 
{
    return TInfo_new(self->doc_freq, self->post_filepos, self->skip_filepos,
        self->lex_filepos);
}

/* TODO: this should probably be some sort of Dump variant rather than
 * To_String.
 */
CharBuf*
TInfo_to_string(TermInfo *self)
{
    return CB_newf(
        "doc freq:      %i32\n"
        "post filepos:  %i64\n"
        "skip filepos:  %i64\n" 
        "index filepos: %i64",
        self->doc_freq, self->post_filepos,
        self->skip_filepos, self->lex_filepos
    );
}

void
TInfo_copy(TermInfo *self, const TermInfo *other) 
{
    self->doc_freq      = other->doc_freq;
    self->post_filepos  = other->post_filepos;
    self->skip_filepos  = other->skip_filepos;
    self->lex_filepos   = other->lex_filepos;
}

void
TInfo_reset(TermInfo *self) 
{
    self->doc_freq      = 0;
    self->post_filepos  = 0;
    self->skip_filepos  = 0;
    self->lex_filepos   = 0;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

