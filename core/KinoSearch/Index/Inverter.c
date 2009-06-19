#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/Inverter.h"
#include "KinoSearch/Analysis/Analyzer.h"
#include "KinoSearch/Analysis/Token.h"
#include "KinoSearch/Analysis/Inversion.h"
#include "KinoSearch/Doc.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/FieldType/FullTextType.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Search/Similarity.h"

Inverter*
Inverter_new(Schema *schema, Segment *segment)
{
    Inverter *self = (Inverter*)VTable_Make_Obj(&INVERTER);
    return Inverter_init(self, schema, segment);
}

Inverter*
Inverter_init(Inverter *self, Schema *schema, Segment *segment)
{
    /* Init. */
    self->tick       = -1;
    self->doc        = NULL;
    self->sorted     = false;
    self->blank      = InvEntry_new(NULL, NULL, 0);
    self->current    = self->blank;
    
    /* Derive. */
    self->entry_pool = VA_new(Schema_Num_Fields(schema));
    self->entries    = VA_new(Schema_Num_Fields(schema));

    /* Assign. */
    self->schema  = (Schema*)INCREF(schema);
    self->segment = (Segment*)INCREF(segment);

    return self;
}

void
Inverter_destroy(Inverter *self) 
{
    Inverter_Clear(self);
    DECREF(self->blank);
    DECREF(self->entries);
    DECREF(self->entry_pool);
    DECREF(self->schema);
    DECREF(self->segment);
    FREE_OBJ(self);
}

u32_t
Inverter_iter_init(Inverter *self)
{
    self->tick = -1;
    if (!self->sorted) { 
        VA_Sort(self->entries, NULL); 
        self->sorted = true;
    }
    return VA_Get_Size(self->entries);
}

i32_t
Inverter_next(Inverter *self)
{
    self->current = (InverterEntry*)VA_Fetch(self->entries, ++self->tick);
    if (!self->current) { self->current = self->blank; } /* Exhausted. */
    return self->current->field_num; 
}

void
Inverter_set_doc(Inverter *self, Doc *doc)
{
    Inverter_Clear(self); /* Zap all cached field values and Inversions. */
    self->doc = (Doc*)INCREF(doc);
}

void
Inverter_set_boost(Inverter *self, float boost)
{ self->boost = boost; }

float
Inverter_get_boost(Inverter *self)
{ return self->boost; }

Doc*
Inverter_get_doc(Inverter *self)
{ return self->doc; }

CharBuf*
Inverter_get_field_name(Inverter *self)
{ return self->current->field; }

ViewCharBuf*
Inverter_get_value(Inverter *self)
{ return self->current->value; }

FieldType*
Inverter_get_type(Inverter *self)
{ return self->current->type; }

Analyzer*
Inverter_get_analyzer(Inverter *self)
{ return self->current->analyzer; }

Similarity*
Inverter_get_similarity(Inverter *self)
{ return self->current->sim; }

Inversion*
Inverter_get_inversion(Inverter *self)
{ return self->current->inversion; }


void
Inverter_add_field(Inverter *self, InverterEntry *entry, Obj *value)
{
    /* Cache value. */
    if (!OBJ_IS_A(value, CHARBUF))
        THROW("Can't handle non-string value for field '%o'", entry->field);
    ViewCB_Assign(entry->value, (CharBuf*)value);

    /* Get an Inversion, going through analyzer if appropriate. */
    if (entry->analyzer) {
        DECREF(entry->inversion);
        entry->inversion
            = Analyzer_Transform_Text(entry->analyzer, (CharBuf*)entry->value);
        Inversion_Invert(entry->inversion);
    }
    else if (entry->indexed || entry->highlightable) {
        size_t token_len = ViewCB_Get_Size(entry->value);
        Token *seed = Token_new((char*)ViewCB_Get_Ptr8(entry->value), token_len, 
            0, token_len, 1.0f, 1);
        DECREF(entry->inversion);
        entry->inversion = Inversion_new(seed);
        DECREF(seed);
        Inversion_Invert(entry->inversion); /* Nearly a no-op. */
    }

    /* Prime the iterator. */
    VA_Push(self->entries, INCREF(entry));
    self->sorted = false;
}

void
Inverter_clear(Inverter *self)
{
    u32_t i, max;
    for (i = 0, max = VA_Get_Size(self->entries); i < max; i++) {
        InvEntry_Clear(VA_Fetch(self->entries, i));
    }
    VA_Clear(self->entries);
    self->tick = -1;
    DECREF(self->doc);
    self->doc = NULL;
}

InverterEntry*
InvEntry_new(Schema *schema, const CharBuf *field_name, i32_t field_num)
{
    InverterEntry *self = (InverterEntry*)VTable_Make_Obj(&INVERTERENTRY);
    return InvEntry_init(self, schema, field_name, field_num);
}

static char EMPTY_CHARS[] = "";

InverterEntry*
InvEntry_init(InverterEntry *self, Schema *schema, const CharBuf *field_name,
              i32_t field_num)
{
    self->field_num  = field_num;
    self->field      = field_name ? CB_Clone(field_name) : NULL;
    self->inversion  = NULL;

    if (schema) {
        self->value      = ViewCB_new_from_trusted_utf8((char*)&EMPTY_CHARS, 0);
        self->analyzer   = Schema_Fetch_Analyzer(schema, field_name);
        self->sim        = Schema_Fetch_Sim(schema, field_name);
        self->type       = Schema_Fetch_Type(schema, field_name);
        if (self->sim)      { INCREF(self->sim); }
        if (self->analyzer) { INCREF(self->analyzer); }
        if (self->type)     { INCREF(self->type); }
        else                { THROW("Unknown field: '%o'", field_name); }
        self->indexed    = FType_Indexed(self->type);
        self->binary     = FType_Binary(self->type);
        if (OBJ_IS_A(self->type, FULLTEXTTYPE)) {
            self->highlightable = FullTextType_Highlightable(self->type);
        }
    }
    return self;
}

void
InvEntry_destroy(InverterEntry *self)
{
    DECREF(self->field);
    DECREF(self->value);
    DECREF(self->analyzer);
    DECREF(self->type);
    DECREF(self->sim);
    DECREF(self->inversion);
    FREE_OBJ(self);
}

void
InvEntry_clear(InverterEntry *self)
{
    DECREF(self->inversion);
    self->inversion = NULL;
    if (self->value) { 
        ViewCB_Assign_Str(self->value, (char*)&EMPTY_CHARS, 0);
    }
}

i32_t
InvEntry_compare_to(InverterEntry *self, Obj *other)
{
    InverterEntry *competitor = (InverterEntry*)other;
    return self->field_num - competitor->field_num;
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

