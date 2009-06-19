#include "KinoSearch/Util/ToolSet.h"

#include <stdio.h>
#include <ctype.h>

#include "KinoSearch/Util/Stepper.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/StringHelper.h"

/* Indent and prepend iter number onto a the string representation of this
 * Stepper.
 */
static void
S_format_charbuf(CharBuf *charbuf, u32_t iter);

Stepper*
Stepper_init(Stepper *self)
{
    ABSTRACT_CLASS_CHECK(self, STEPPER);
    return self;
}

static void
S_format_charbuf(CharBuf *charbuf, u32_t iter)
{
    char *source, *dest;
    char iter_buf[12];

    /* Indent and prepend iter number. */
    StrHelp_add_indent(charbuf, 12);
    sprintf(iter_buf, "%lu", (unsigned long)iter);
    source = iter_buf;
    dest   = charbuf->ptr;
    while (isdigit(*source)) {
        *dest++ = *source++;
    }
    CB_Cat_Trusted_Str(charbuf, "\n", 1);
}

void
Stepper_dump_to_file(Stepper *self, InStream *instream, OutStream *outstream)
{
    i64_t end  = InStream_Length(instream);
    u32_t iter = 0;

    while (InStream_Tell(instream) < end) {
        CharBuf *string;

        Stepper_Read_Record(self, instream);
        string = Stepper_To_String(self);
        S_format_charbuf(string, iter++);
        OutStream_Write_Bytes(outstream, string->ptr, CB_Get_Size(string));
        DECREF(string);
    }
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

