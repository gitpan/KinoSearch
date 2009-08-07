#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Store/FileWindow.h"

FileWindow*
FileWindow_new(char *buf, i64_t offset, i64_t len, i64_t cap)
{
    FileWindow *self = (FileWindow*)VTable_Make_Obj(FILEWINDOW);
    return FileWindow_init(self, buf, offset, len, cap);
}

FileWindow*
FileWindow_init(FileWindow *self, char *buf, i64_t offset, i64_t len, 
                i64_t cap)
{
    self->buf     = buf;
    self->offset  = offset;
    self->len     = len;
    self->cap     = cap;
    return self;
}

void
FileWindow_set_offset(FileWindow *self, i64_t offset)
{
    if (self->buf != NULL) {
        if (offset != self->offset) {
            THROW(ERR, "Can't set offset to %i64 instead of %i64 unless buf "
                "is NULL", offset, self->offset);
        }
    }
    self->offset = offset;
}

/* Copyright 2008-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

