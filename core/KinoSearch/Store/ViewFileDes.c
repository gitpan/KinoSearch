#define C_KINO_VIEWFILEDES
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Store/ViewFileDes.h"

ViewFileDes*
ViewFileDes_new(char *ptr, size_t len) 
{
    ViewFileDes *self = (ViewFileDes*)VTable_Make_Obj(VIEWFILEDES);
    return ViewFileDes_init(self, ptr, len);
}

ViewFileDes*
ViewFileDes_init(ViewFileDes *self, char *ptr, size_t len) 
{
    RAMFileDes_init((RAMFileDes*)self, NULL);
    self->len = len;
    VA_Push(self->buffers, (Obj*)ViewBB_new(ptr, len));
    return self;
}

bool_t
ViewFileDes_write(ViewFileDes *self, const void *buf, u32_t len) 
{
    UNUSED_VAR(self);
    UNUSED_VAR(buf);
    UNUSED_VAR(len);
    if (!self->mess) self->mess = CB_new(30);
    CB_catf(self->mess, "Can't write to ViewFileDes");
    return false;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

