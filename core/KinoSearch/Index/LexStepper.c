#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/LexStepper.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/StringHelper.h"

/* Read in a term's worth of data from the input stream.
 */
static void
S_read_term_text(LexStepper *self, InStream *instream);

/* Read in a TermInfo from the input stream.
 */
static void
S_read_tinfo(LexStepper *self, InStream *instream);

LexStepper*
LexStepper_new(const CharBuf *field, u32_t skip_interval)
{
    LexStepper *self = (LexStepper*)VTable_Make_Obj(&LEXSTEPPER);
    return LexStepper_init(self, field, skip_interval);
}

LexStepper*
LexStepper_init(LexStepper *self, const CharBuf *field, u32_t skip_interval)
{
    Stepper_init((Stepper*)self);

    /* Assign. */
    self->field          = CB_Clone(field);
    self->skip_interval  = skip_interval;

    /* Init. */
    self->value          = NULL;
    self->tinfo          = TInfo_new(0,0,0,0);

    return self;
}

void
LexStepper_destroy(LexStepper *self)
{
    DECREF(self->field);
    DECREF(self->value);
    DECREF(self->tinfo);
    FREE_OBJ(self);
}

CharBuf*
LexStepper_to_string(LexStepper *self)
{
    if (self->value == NULL) {
        return CB_new_from_trusted_utf8("(empty)", 7);
    }
    else {
        CharBuf *string    = Obj_To_String(self->value);
        CharBuf *tinfo_str = TInfo_To_String(self->tinfo);

        CB_Cat_Trusted_Str(string, "\n", 1);
        StrHelp_add_indent(tinfo_str, 4);
        CB_Cat(string, tinfo_str);

        DECREF(tinfo_str);

        return string;
    }
}


void 
LexStepper_write_record(LexStepper* self, OutStream *outstream, 
                        const char *term_text,
                        size_t term_text_len, 
                        const char *last_text, 
                        size_t last_text_len,
                        TermInfo* tinfo, 
                        TermInfo *last_tinfo)
{
    /* Count how many bytes the strings share at the top. */ 
    const i32_t overlap = StrHelp_string_diff(last_text, term_text,
        last_text_len, term_text_len);
    const char *const diff_start_str = term_text + overlap;
    const size_t diff_len            = term_text_len - overlap;

    /* Write number of common bytes and common bytes. */
    OutStream_Write_C32(outstream, overlap);
    OutStream_Write_String(outstream, diff_start_str, diff_len);
    
    /* Write doc_freq. */
    OutStream_Write_C32(outstream, tinfo->doc_freq);

    /* Delta encode filepointers. */
    OutStream_Write_C64(outstream, 
        (tinfo->post_filepos - last_tinfo->post_filepos) );

    /* Write skipdata. */
    if (tinfo->doc_freq >= self->skip_interval)
        OutStream_Write_C64(outstream, tinfo->skip_filepos);
}

void
LexStepper_read_record(LexStepper *self, InStream *instream)
{ 
    S_read_term_text(self, instream);
    S_read_tinfo(self, instream);
}

void
LexStepper_reset(LexStepper *self)
{
    DECREF(self->value);
    self->value = NULL;
    TInfo_Reset(self->tinfo);
}

void
LexStepper_set_value(LexStepper *self, const Obj *value)
{
    DECREF(self->value);
    self->value = value == NULL ? NULL : Obj_Clone(value);
}

void
LexStepper_set_tinfo(LexStepper *self, const TermInfo *tinfo)
{
    TInfo_Copy(self->tinfo, tinfo);
}

void
LexStepper_copy(LexStepper *self, LexStepper *other)
{
    LexStepper_Set_Value(self, other->value);
    LexStepper_Set_TInfo(self, other->tinfo);
}

static void
S_read_term_text(LexStepper *self, InStream *instream)
{
    const u32_t text_overlap     = InStream_Read_C32(instream);
    const u32_t finish_chars_len = InStream_Read_C32(instream);
    const u32_t total_text_len   = text_overlap + finish_chars_len;
    CharBuf *value;

    /* Allocate space. */
    if (self->value == NULL) {
        self->value = (Obj*)CB_new(total_text_len);
    }
    value = (CharBuf*)self->value;
    CB_Grow(value, total_text_len);

    /* Set the term text. */
    InStream_Read_BytesO(instream, (char*)CB_Get_Ptr8(value), text_overlap,
        finish_chars_len);
    CB_Set_Size(value, total_text_len);

    /* Null-terminate. */
    *(value->ptr + total_text_len) = '\0';
}

void
S_read_tinfo(LexStepper *self, InStream *instream)
{
    TermInfo *const tinfo = self->tinfo;

    /* Read doc freq. */
    tinfo->doc_freq = InStream_Read_C32(instream);

    /* Adjust file pointer. */
    tinfo->post_filepos += InStream_Read_C64(instream);

    /* Read skip data. */
    if (tinfo->doc_freq >= self->skip_interval)
        tinfo->skip_filepos = InStream_Read_C64(instream);
    else
        tinfo->skip_filepos = 0;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

