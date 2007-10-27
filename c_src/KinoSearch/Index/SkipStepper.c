#include <stdio.h>

#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SKIPSTEPPER_VTABLE
#include "KinoSearch/Index/SkipStepper.r"

#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/OutStream.r"

SkipStepper*
SkipStepper_new()
{
    CREATE(self, SkipStepper, SKIPSTEPPER);

    /* init */
    self->doc_num  = 0;
    self->filepos  = 0;

    return self;
}

void
SkipStepper_reset(SkipStepper *self, u32_t doc_num, u64_t filepos)
{
    self->doc_num = doc_num;
    self->filepos = filepos;
}

void
SkipStepper_read_record(SkipStepper *self, InStream *instream)
{
    self->doc_num  += InStream_Read_VInt(instream);
    self->filepos  += InStream_Read_VLong(instream);
}

ByteBuf*
SkipStepper_to_string(SkipStepper *self)
{
    char *ptr = MALLOCATE(60, char);
    sprintf(ptr, "skip doc: %u file pointer: %" U64P, self->doc_num,
        self->filepos);
    return BB_new_steal(ptr, strlen(ptr), 60);
}

void
SkipStepper_write_record(SkipStepper *self, OutStream *outstream, 
    u32_t last_doc_num, u64_t last_filepos)
{
    const u32_t delta_doc_num = self->doc_num - last_doc_num;
    const u64_t delta_filepos = self->filepos - last_filepos;

    /* write delta doc num */
    OutStream_Write_VInt(outstream, delta_doc_num);

    /* write delta file pointer */
    OutStream_Write_VLong(outstream, (u64_t)delta_filepos);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */


