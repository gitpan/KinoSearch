#define C_KINO_SKIPSTEPPER
#include <stdio.h>

#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SkipStepper.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"

SkipStepper*
SkipStepper_new()
{
    SkipStepper *self = (SkipStepper*)VTable_Make_Obj(SKIPSTEPPER);

    // Init. 
    self->doc_id   = 0;
    self->filepos  = 0;

    return self;
}

void
SkipStepper_set_id_and_filepos(SkipStepper *self, int32_t doc_id, int64_t filepos)
{
    self->doc_id  = doc_id;
    self->filepos = filepos;
}

void
SkipStepper_read_record(SkipStepper *self, InStream *instream)
{
    self->doc_id   += InStream_Read_C32(instream);
    self->filepos  += InStream_Read_C64(instream);
}

CharBuf*
SkipStepper_to_string(SkipStepper *self)
{
    char *ptr = (char*)MALLOCATE(60);
    size_t len = sprintf(ptr, "skip doc: %u file pointer: %" I64P, 
        self->doc_id, self->filepos);
    return CB_new_steal_from_trusted_str(ptr, len, 60);
}

void
SkipStepper_write_record(SkipStepper *self, OutStream *outstream, 
    int32_t last_doc_id, int64_t last_filepos)
{
    const int32_t delta_doc_id = self->doc_id - last_doc_id;
    const int64_t delta_filepos = self->filepos - last_filepos;

    // Write delta doc id. 
    OutStream_Write_C32(outstream, delta_doc_id);

    // Write delta file pointer. 
    OutStream_Write_C64(outstream, delta_filepos);
}

/* Copyright 2007-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */


