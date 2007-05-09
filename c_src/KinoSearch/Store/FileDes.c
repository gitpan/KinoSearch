#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>

#define KINO_WANT_FILEDES_VTABLE
#include "KinoSearch/Store/FileDes.r"

i32_t kino_FileDes_object_count = 0;
i32_t kino_FileDes_open_count = 0;

bool_t
FileDes_fdseek(FileDes *self, u64_t target)
{
    UNUSED_VAR(target);
    ABSTRACT_DEATH(self, "FDSeek");
    UNREACHABLE_RETURN(bool_t);
}

bool_t
FileDes_fdread(FileDes *self, char *dest, u32_t dest_offset, u32_t len)
{
    UNUSED_VAR(dest);
    UNUSED_VAR(dest_offset);
    UNUSED_VAR(len);
    ABSTRACT_DEATH(self, "FDRead");
    UNREACHABLE_RETURN(bool_t);
}

bool_t
FileDes_fdwrite(FileDes *self, const char* buf, u32_t len) 
{
    UNUSED_VAR(buf);
    UNUSED_VAR(len);
    ABSTRACT_DEATH(self, "FDWrite");
    UNREACHABLE_RETURN(bool_t);
}

u64_t
FileDes_fdlength(FileDes *self)
{
    ABSTRACT_DEATH(self, "FDLength");
    UNREACHABLE_RETURN(u64_t);
}

bool_t
FileDes_fdclose(FileDes *self)
{
    ABSTRACT_DEATH(self, "FDClose");
    UNREACHABLE_RETURN(bool_t);
}


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

