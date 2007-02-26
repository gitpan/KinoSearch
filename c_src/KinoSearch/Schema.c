#include <string.h>
#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCHEMA_VTABLE
#include "KinoSearch/Schema.r"

#include "KinoSearch/Schema/FieldSpec.r"
#include "KinoSearch/Util/CClass.r"
#include "KinoSearch/Search/Similarity.r"

Schema*
Schema_new(const char *class_name, Hash *fspecs, Hash *sims, Similarity *sim)
{
    CREATE_SUBCLASS(self, class_name, Schema, SCHEMA);

    /* assign */
    REFCOUNT_INC(fspecs);
    REFCOUNT_INC(sims);
    REFCOUNT_INC(sim);
    self->fspecs = fspecs;
    self->sims   = sims;
    self->sim    = sim;

    /* init */
    self->analyzer    = NULL;
    self->analyzers   = NULL;

    return self;
}

FieldSpec*
Schema_fetch_fspec(Schema *self, const ByteBuf *field_name)
{
    return (FieldSpec*)Hash_Fetch_BB(self->fspecs, field_name);
}

Similarity*
Schema_fetch_sim(Schema *self, const ByteBuf *field_name)
{
    Similarity *sim =  (Similarity*)Hash_Fetch_BB(self->sims, field_name);
    if (sim == NULL)
        return self->sim;
    else 
        return sim;
}

kino_u32_t
kino_Schema_num_fields(kino_Schema *self)
{
    return self->fspecs->size;
}

void
Schema_destroy(Schema *self) 
{
    CClass_svrefcount_dec(self->analyzer);
    CClass_svrefcount_dec(self->analyzers);
    REFCOUNT_DEC(self->fspecs);
    REFCOUNT_DEC(self->sims);
    REFCOUNT_DEC(self->sim);
    free(self);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

