#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>

#define KINO_WANT_FILEDES_VTABLE
#include "KinoSearch/Store/FileDes.r"

i32_t kino_FileDes_global_count = 0;

void
FileDes_fdseek(FileDes *self, u64_t target)
{
    UNUSED_VAR(self);
    UNUSED_VAR(target);
    CONFESS("FileDes_FDSeek must be defined in a subclass");
}

void
FileDes_fdread(FileDes *self, char *dest, u32_t dest_offset, u32_t len)
{
    UNUSED_VAR(self);
    UNUSED_VAR(dest);
    UNUSED_VAR(dest_offset);
    UNUSED_VAR(len);
    CONFESS("FileDes_FDRead must be defined in a subclass");
}

void
FileDes_fdwrite(FileDes *self, char* buf, u32_t len) 
{
    UNUSED_VAR(self);
    UNUSED_VAR(buf);
    UNUSED_VAR(len);
    CONFESS("FileDes_FDWrite must be defined in a subclass");
}

u64_t
FileDes_fdlength(FileDes *self)
{
    UNUSED_VAR(self);
    CONFESS("FileDes_FDLength must be defined in a subclass");
    UNREACHABLE_RETURN(u64_t);
}

void
FileDes_fdclose(FileDes *self)
{
    UNUSED_VAR(self);
    CONFESS("FileDes_FDClose must be defined in a subclass");
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

