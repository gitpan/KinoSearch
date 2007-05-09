#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_FIELDDOC_VTABLE
#include "KinoSearch/Search/FieldDoc.r"

#include "KinoSearch/Search/FieldDocCollator.r"

FieldDoc*
FieldDoc_new(u32_t doc_num, float score, FieldDocCollator *collator)
{
    CREATE(self, FieldDoc, FIELDDOC);

    /* assign */
    self->doc_num  = doc_num;
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

