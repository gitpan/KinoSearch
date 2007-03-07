#include <string.h>
#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCHEMA_VTABLE
#include "KinoSearch/Schema.r"

#include "KinoSearch/Schema/FieldSpec.r"
#include "KinoSearch/Util/CClass.r"
#include "KinoSearch/Search/Similarity.r"

Schema*
Schema_new(const char *class_name, void *analyzer, void *analyzers, 
           Similarity *sim)
{
    CREATE_SUBCLASS(self, class_name, Schema, SCHEMA);

    /* assign */
    CClass_svrefcount_inc(analyzer);
    CClass_svrefcount_inc(analyzers);
    REFCOUNT_INC(sim);
    self->analyzer    = analyzer;
    self->analyzers   = analyzers;
    self->sim         = sim;

    /* init */
    self->fspecs      = Hash_new(0);
    self->sims        = Hash_new(0);

    return self;
}

void
Schema_add_field(Schema *self, const ByteBuf *field_name, FieldSpec *fspec)
{
    Hash_Store_BB(self->fspecs, field_name, (Obj*)fspec);
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

