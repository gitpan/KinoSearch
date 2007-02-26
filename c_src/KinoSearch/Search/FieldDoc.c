#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_FIELDDOC_VTABLE
#include "KinoSearch/Search/FieldDoc.r"

#include "KinoSearch/Search/FieldDocCollator.r"

FieldDoc*
FieldDoc_new(kino_u32_t id, float score, FieldDocCollator *collator)
{
    CREATE(self, FieldDoc, FIELDDOC);

    /* assign */
    self->id       = id;
    self->score    = score;
    REFCOUNT_INC(collator);
    self->collator = collator;

    return self;
}

void
FieldDoc_destroy(FieldDoc *self)
{
    REFCOUNT_DEC(self->collator);
    free(self);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

