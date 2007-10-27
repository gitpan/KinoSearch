#include "KinoSearch/Util/ToolSet.h"

#include <stdio.h>
#include <ctype.h>

#define KINO_WANT_STEPPER_VTABLE
#include "KinoSearch/Util/Stepper.r"

#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Util/StringHelper.h"

/* Indent and prepend iter number onto a the string representation of this
 * Stepper.
 */
static void
format_bb(ByteBuf *bb, u32_t iter);

void
Stepper_read_record(Stepper *self, InStream *instream) 
{
    UNUSED_VAR(instream);
    ABSTRACT_DEATH(self, "Read_Record");
}

static void
format_bb(ByteBuf *bb, u32_t iter)
{
    char *source, *dest;
    char iter_buf[12];

    /* indent and prepend iter number */
    StrHelp_add_indent(bb, 12);
    sprintf(iter_buf, "%lu", (unsigned long)iter);
    source = iter_buf;
    dest   = bb->ptr;
    while (isdigit(*source)) {
        *dest++ = *source++;
    }
    BB_Cat_Str(bb, "\n", 1);
}

void
Stepper_dump(Stepper *self, InStream *instream)
{
    u64_t end  = InStream_SLength(instream);
    u32_t iter = 0;

    while (InStream_STell(instream) < end) {
        ByteBuf *string;

        Stepper_Read_Record(self, instream);
        string = Stepper_To_String(self);
        format_bb(string, iter++);
        printf("%s", string->ptr);
        REFCOUNT_DEC(string);
    }
}

void
Stepper_dump_to_file(Stepper *self, InStream *instream, OutStream *outstream)
{
    u64_t end  = InStream_SLength(instream);
    u32_t iter = 0;

    while (InStream_STell(instream) < end) {
        ByteBuf *string;

        Stepper_Read_Record(self, instream);
        string = Stepper_To_String(self);
        format_bb(string, iter++);
        OutStream_Write_Bytes(outstream, string->ptr, string->len);
        REFCOUNT_DEC(string);
    }
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

