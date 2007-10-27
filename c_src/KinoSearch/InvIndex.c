#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_INVINDEX_VTABLE
#include "KinoSearch/InvIndex.r"

#include "KinoSearch/Schema.r"
#include "KinoSearch/Store/Folder.r"

InvIndex*
InvIndex_new(Schema *schema, Folder *folder)
{
    CREATE(self, InvIndex, INVINDEX);

    /* assign */
    self->schema = REFCOUNT_INC(schema);
    self->folder = REFCOUNT_INC(folder);

    return self;
}

void
InvIndex_destroy(InvIndex *self) 
{
    REFCOUNT_DEC(self->schema);
    REFCOUNT_DEC(self->folder);
    free(self);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

