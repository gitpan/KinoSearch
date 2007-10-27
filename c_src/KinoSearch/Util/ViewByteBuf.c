#define KINO_USE_SHORT_NAMES

#include <string.h>

#define KINO_WANT_VIEWBYTEBUF_VTABLE
#include "KinoSearch/Util/ViewByteBuf.r"

#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/MemManager.h"

ViewByteBuf*
ViewBB_new(char *ptr, size_t len) 
{
    CREATE(self, ViewByteBuf, VIEWBYTEBUF);

    /* init */
    self->cap = 0;

    /* assign */
    self->ptr  = ptr;
    self->len  = len;
    
    return self;
}

void
ViewBB_assign(ViewByteBuf *self, char*ptr, size_t len) 
{
    self->ptr = ptr;
    self->len = len;
}

void 
ViewBB_destroy(ViewByteBuf *self) 
{
    free(self);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

