#include <string.h>
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SCHEMA_VTABLE
#include "KinoSearch/Schema.r"

#include "KinoSearch/Posting.r"
#include "KinoSearch/FieldSpec.r"
#include "KinoSearch/Util/Native.r"
#include "KinoSearch/Util/Int.r"
#include "KinoSearch/Search/Similarity.r"

Schema*
Schema_new(const char *class_name, void *analyzer, void *analyzers, 
           Similarity *sim, i32_t index_interval, i32_t skip_interval)
{
    CREATE_SUBCLASS(self, class_name, Schema, SCHEMA);

    /* assign */
    self->analyzer           = Native_new(analyzer);
    self->analyzers          = Native_new(analyzers);
    self->sim                = REFCOUNT_INC(sim);
    self->index_interval     = index_interval;
    self->skip_interval      = skip_interval;

    /* init */
    self->fspecs      = Hash_new(0);
    self->sims        = Hash_new(0);
    self->by_name     = Hash_new(0);
    self->by_num      = VA_new(0);

    return self;
}

void
Schema_add_field(Schema *self, const ByteBuf *field_name, FieldSpec *fspec)
{
    if ( (Hash_Fetch_BB(self->fspecs, field_name)) == NULL) {
        Int *num = Int_new(self->by_num->size);
        ByteBuf *name_copy = BB_CLONE(field_name);
        VA_Push(self->by_num, (Obj*)name_copy);
        Hash_Store_BB(self->fspecs, name_copy, (Obj*)fspec);
        Hash_Store_BB(self->by_name, name_copy, (Obj*)num);
        REFCOUNT_DEC(name_copy);
        REFCOUNT_DEC(num);
    }
}

FieldSpec*
Schema_fetch_fspec(Schema *self, const ByteBuf *field_name)
{
    return (FieldSpec*)Hash_Fetch_BB(self->fspecs, field_name);
}

Similarity*
Schema_fetch_sim(Schema *self, const ByteBuf *field_name)
{
    if (field_name != NULL) {
        Similarity *sim = (Similarity*)Hash_Fetch_BB(self->sims, field_name);
        if (sim != NULL)
            return sim;
    }        
    
    return self->sim;
}

Posting*
Schema_fetch_posting(Schema *self, const ByteBuf *field_name)
{
    Similarity *sim  = Schema_Fetch_Sim(self, field_name);
    FieldSpec *fspec = (FieldSpec*)Hash_Fetch_BB(self->fspecs, field_name);

    if (fspec == NULL)
        CONFESS("Can't Fetch_Posting for unknown field %s", field_name->ptr);

    return Post_Dupe(fspec->posting, sim);
}

chy_u32_t
kino_Schema_num_fields(kino_Schema *self)
{
    return self->fspecs->size;
}

i32_t
Schema_field_num(Schema *self, const ByteBuf *field_name)
{
    if (field_name == NULL) {
        return -1;
    }
    else {
        Int *num = (Int*)Hash_Fetch_BB(self->by_name, field_name);
        if (num == NULL)
            return -1;
        return num->value;
    }
}

VArray*
Schema_all_fields(Schema *self)
{
    return Hash_Keys(self->fspecs);
}

void
Schema_destroy(Schema *self) 
{
    REFCOUNT_DEC(self->analyzer);
    REFCOUNT_DEC(self->analyzers);
    REFCOUNT_DEC(self->fspecs);
    REFCOUNT_DEC(self->by_name);
    REFCOUNT_DEC(self->by_num);
    REFCOUNT_DEC(self->sims);
    REFCOUNT_DEC(self->sim);
    free(self);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

