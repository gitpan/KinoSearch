#define C_KINO_FOLDER
#include "KinoSearch/Util/ToolSet.h"
#include <ctype.h>

#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/FileDes.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/Lock.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/Compat/DirManip.h"


Folder*
Folder_init(Folder *self, const CharBuf *path)
{
    /* Copy. */
    if (path == NULL) {
        self->path = CB_new_from_trusted_utf8("", 0);
    }
    else {
        /* Copy path, absolutify it, strip trailing slash or equivalent. */
        self->path = DirManip_absolutify(path);
        if (CB_Ends_With_Str(self->path, DIR_SEP, strlen(DIR_SEP)))
            CB_Chop(self->path, 1);
    }

    ABSTRACT_CLASS_CHECK(self, FOLDER);
    return self;
}

void
Folder_destroy(Folder *self)
{
    DECREF(self->path);
    SUPER_DESTROY(self, FOLDER);
}

InStream*
Folder_open_in(Folder *self, const CharBuf *filename)
{
    FileDes  *file_des = Folder_Open_FileDes(self, filename);
    InStream *instream = NULL;
    if (file_des) { 
        instream = InStream_new(file_des);
        DECREF(file_des);
    }
    return instream;
}

ByteBuf*
Folder_slurp_file(Folder *self, const CharBuf *filename)
{
    InStream *instream = Folder_Open_In(self, filename);
    ByteBuf  *retval   = NULL;

    if (!instream) {
        THROW(ERR, "Can't open '%o'", filename);
    }
    else {
        size_t size = (size_t)InStream_Length(instream);

        if (size > I32_MAX) {
            InStream_Close(instream);
            DECREF(instream);
            THROW(ERR, "File %o is too big to slurp (%u64 bytes)", filename, size);
        } 
        else {
            char *ptr = MALLOCATE(size + 1, char);
            InStream_Read_Bytes(instream, ptr, size);
            ptr[size] = '\0';
            retval = BB_new_steal_bytes(ptr, size, size + 1);
            InStream_Close(instream);
            DECREF(instream);
        }
    }

    return retval;
}

CharBuf*
Folder_get_path(Folder *self) { return self->path; }

void
Folder_finish_segment(Folder *self, const CharBuf *seg_name)
{
    UNUSED_VAR(self);
    UNUSED_VAR(seg_name);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

