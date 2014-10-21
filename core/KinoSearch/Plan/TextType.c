#define C_KINO_TEXTTYPE
#define C_KINO_TEXTTERMSTEPPER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Plan/TextType.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/StringHelper.h"

CharBuf*
TextType_make_blank(TextType *self)
{
    UNUSED_VAR(self);
    return CB_new(0);
}

TermStepper*
TextType_make_term_stepper(TextType *self)
{
    UNUSED_VAR(self);
    return (TermStepper*)TextTermStepper_new();
}

int8_t
TextType_primitive_id(TextType *self)
{
    UNUSED_VAR(self);
    return FType_TEXT;
}

/***************************************************************************/

TextTermStepper*
TextTermStepper_new()
{
    TextTermStepper *self 
        = (TextTermStepper*)VTable_Make_Obj(TEXTTERMSTEPPER);
    return TextTermStepper_init(self);
}

TextTermStepper*
TextTermStepper_init(TextTermStepper *self)
{
    TermStepper_init((TermStepper*)self);
    self->value = (Obj*)CB_new(0);
    return self;
}

void
TextTermStepper_set_value(TextTermStepper *self, Obj *value)
{
    CERTIFY(value, CHARBUF);
    DECREF(self->value);
    self->value = INCREF(value);
}

void
TextTermStepper_reset(TextTermStepper *self)
{
    CB_Set_Size((CharBuf*)self->value, 0);
}

void
TextTermStepper_write_key_frame(TextTermStepper *self, OutStream *outstream,
                                Obj *value)
{
    Obj_Serialize(value, outstream);
    Obj_Mimic(self->value, value);
}

void
TextTermStepper_write_delta(TextTermStepper *self, OutStream *outstream,
                            Obj *value)
{
    CharBuf *new_value  = (CharBuf*)CERTIFY(value, CHARBUF);
    CharBuf *last_value = (CharBuf*)self->value;
    char    *new_text  = (char*)CB_Get_Ptr8(new_value);
    size_t   new_size  = CB_Get_Size(new_value);
    char    *last_text = (char*)CB_Get_Ptr8(last_value);
    size_t   last_size = CB_Get_Size(last_value);

    // Count how many bytes the strings share at the top.  
    const int32_t overlap = StrHelp_overlap(last_text, new_text,
        last_size, new_size);
    const char *const diff_start_str = new_text + overlap;
    const size_t diff_len            = new_size - overlap;

    // Write number of common bytes and common bytes. 
    OutStream_Write_C32(outstream, overlap);
    OutStream_Write_String(outstream, diff_start_str, diff_len);

    // Update value. 
    CB_Mimic((CharBuf*)self->value, value);
}

void
TextTermStepper_read_key_frame(TextTermStepper *self, InStream *instream)
{ 
    const uint32_t text_len = InStream_Read_C32(instream);
    CharBuf *value;
    char *ptr;

    // Allocate space. 
    if (self->value == NULL) {
        self->value = (Obj*)CB_new(text_len);
    }
    value = (CharBuf*)self->value;
    ptr   = CB_Grow(value, text_len);

    // Set the value text. 
    InStream_Read_Bytes(instream, ptr, text_len);
    CB_Set_Size(value, text_len);
    if (!StrHelp_utf8_valid(ptr, text_len)) {
        THROW(ERR, "Invalid UTF-8 sequence in '%o' at byte %i64",
            InStream_Get_Filename(instream), 
            InStream_Tell(instream) - text_len);
    }

    // Null-terminate. 
    ptr[text_len] = '\0';
}

void
TextTermStepper_read_delta(TextTermStepper *self, InStream *instream)
{ 
    const uint32_t text_overlap     = InStream_Read_C32(instream);
    const uint32_t finish_chars_len = InStream_Read_C32(instream);
    const uint32_t total_text_len   = text_overlap + finish_chars_len;
    CharBuf *value;
    char *ptr;

    // Allocate space. 
    if (self->value == NULL) {
        self->value = (Obj*)CB_new(total_text_len);
    }
    value = (CharBuf*)self->value;
    ptr   = CB_Grow(value, total_text_len);

    // Set the value text. 
    InStream_Read_Bytes(instream, ptr + text_overlap, finish_chars_len);
    CB_Set_Size(value, total_text_len);
    if (!StrHelp_utf8_valid(ptr, total_text_len)) {
        THROW(ERR, "Invalid UTF-8 sequence in '%o' at byte %i64",
            InStream_Get_Filename(instream), 
            InStream_Tell(instream) - finish_chars_len);
    }

    // Null-terminate. 
    ptr[total_text_len] = '\0';
}

/* Copyright 2007-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

