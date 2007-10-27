#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TERMSTEPPER_VTABLE
#include "KinoSearch/Index/TermStepper.r"

#include "KinoSearch/Schema.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Util/StringHelper.h"

/* Read in a term's worth of data from the input stream.
 */
static void
read_term_text(TermStepper *self, InStream *instream);

/* Read in a TermInfo from the input stream.
 */
static void
read_tinfo(TermStepper *self, InStream *instream);

TermStepper*
TermStepper_new(const ByteBuf *field, u32_t skip_interval, 
                bool_t is_index)
{
    CREATE(self, TermStepper, TERMSTEPPER);

    /* assign */
    self->field          = BB_CLONE(field);
    self->is_index       = is_index;
    self->skip_interval  = skip_interval;

    /* init */
    self->term           = NULL;

    /* derive */
    self->tinfo          = TInfo_new(0,0,0,0);

    return self;
}

void
TermStepper_destroy(TermStepper *self)
{
    REFCOUNT_DEC(self->field);
    REFCOUNT_DEC(self->term);
    REFCOUNT_DEC(self->tinfo);
    free(self);
}

ByteBuf*
TermStepper_to_string(TermStepper *self)
{
    if (self->term == NULL) {
        return BB_new_str("(empty)", 7);
    }
    else {
        ByteBuf *string = Term_To_String(self->term);
        ByteBuf *tinfo_str = TInfo_To_String(self->tinfo);

        BB_Cat_Str(string, "\n", 1);
        StrHelp_add_indent(tinfo_str, 4);
        BB_Cat_BB(string, tinfo_str);
        REFCOUNT_DEC(tinfo_str);

        return string;
    }
}


void 
TermStepper_write_record(TermStepper* self, OutStream *outstream, 
                         const char *term_text,
                         size_t term_text_len, 
                         const char *last_text, 
                         size_t last_text_len,
                         TermInfo* tinfo, 
                         TermInfo *last_tinfo,
                         u64_t lex_filepos, u64_t last_lex_filepos) 
{
    /* count how many bytes the strings share at the top */ 
    const i32_t overlap = StrHelp_string_diff(last_text, term_text,
        last_text_len, term_text_len);
    const char *const diff_start_str = term_text + overlap;
    const size_t diff_len            = term_text_len - overlap;

    /* write number of common bytes and common bytes */
    OutStream_Write_VInt(outstream, overlap);
    OutStream_Write_String(outstream, diff_start_str, diff_len);
    
    /* write doc_freq */
    OutStream_Write_VInt(outstream, tinfo->doc_freq);

    /* delta encode filepointers */
    OutStream_Write_VLong(outstream, 
        (tinfo->post_filepos - last_tinfo->post_filepos) );

    /* write skipdata */
    if (tinfo->doc_freq >= self->skip_interval)
        OutStream_Write_VInt(outstream, tinfo->skip_filepos);

    /* the .lexx index file gets a pointer to the location of the primary */
    if (self->is_index)
        OutStream_Write_VLong(outstream, (lex_filepos - last_lex_filepos));
}

void
TermStepper_read_record(TermStepper *self, InStream *instream)
{ 
    read_term_text(self, instream);
    read_tinfo(self, instream);
}

void
TermStepper_reset(TermStepper *self)
{
    REFCOUNT_DEC(self->term);
    self->term = NULL;
    TInfo_Reset(self->tinfo);
}

void
TermStepper_set_term(TermStepper *self, const Term *term)
{
    if (term == NULL) {
        REFCOUNT_DEC(self->term);
        self->term = NULL;
    }
    else if (self->term == NULL) {
        self->term = (Term*)Term_Clone(term);
    }
    else {
        Term_Copy(self->term, term);
    }
}

void
TermStepper_set_tinfo(TermStepper *self, const TermInfo *tinfo)
{
    TInfo_Copy(self->tinfo, tinfo);
}

void
TermStepper_copy(TermStepper *self, TermStepper *other)
{
    TermStepper_Set_Term(self, other->term);
    TermStepper_Set_TInfo(self, other->tinfo);
}

static void
read_term_text(TermStepper *self, InStream *instream)
{
    const u32_t text_overlap     = InStream_Read_VInt(instream);
    const u32_t finish_chars_len = InStream_Read_VInt(instream);
    const u32_t total_text_len   = text_overlap + finish_chars_len;
    ByteBuf *term_text;

    /* get the term's text buffer and allocate space */
    if (self->term == NULL) {
        ByteBuf empty = BYTEBUF_BLANK;
        self->term = Term_new(self->field, &empty);
    }
    term_text = self->term->text;
    BB_GROW(term_text, total_text_len);

    /* set the term text */
    term_text->len = total_text_len;
    InStream_Read_BytesO(instream, term_text->ptr, text_overlap,
        finish_chars_len);

    /* null-terminate */
    *(term_text->ptr + total_text_len) = '\0';
}

void
read_tinfo(TermStepper *self, InStream *instream)
{
    TermInfo *const tinfo = self->tinfo;

    /* read doc freq */
    tinfo->doc_freq = InStream_Read_VInt(instream);

    /* adjust file pointer. */
    tinfo->post_filepos += InStream_Read_VLong(instream);

    /* read skip data */
    if (tinfo->doc_freq >= self->skip_interval)
        tinfo->skip_filepos = InStream_Read_VInt(instream);
    else
        tinfo->skip_filepos = 0;

    /* read filepointer to main enum if this is an index enum */
    if (self->is_index)
        tinfo->index_filepos += InStream_Read_VLong(instream);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

