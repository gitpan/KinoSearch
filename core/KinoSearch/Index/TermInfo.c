#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Util/StringHelper.h"

TermInfo*
TInfo_new(i32_t doc_freq)
{
    TermInfo *self = (TermInfo*)VTable_Make_Obj(TERMINFO);
    return TInfo_init(self, doc_freq);
}

TermInfo*
TInfo_init(TermInfo *self, i32_t doc_freq)
{
    self->doc_freq      = doc_freq;
    self->post_filepos  = 0;
    self->skip_filepos  = 0;
    self->lex_filepos   = 0;
    return self;
}

TermInfo*
TInfo_clone(TermInfo *self) 
{
    TermInfo *evil_twin = TInfo_new(self->doc_freq);
    evil_twin->post_filepos = self->post_filepos;
    evil_twin->skip_filepos = self->skip_filepos;
    evil_twin->lex_filepos  = self->lex_filepos;
    return evil_twin;
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
TInfo_mimic(TermInfo *self, Obj *other) 
{
    TermInfo *evil_twin = (TermInfo*)ASSERT_IS_A(other, TERMINFO);
    self->doc_freq      = evil_twin->doc_freq;
    self->post_filepos  = evil_twin->post_filepos;
    self->skip_filepos  = evil_twin->skip_filepos;
    self->lex_filepos   = evil_twin->lex_filepos;
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

