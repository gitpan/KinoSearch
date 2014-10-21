#define C_KINO_LEAFQUERY
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/LeafQuery.h"
#include "KinoSearch/Search/Compiler.h"
#include "KinoSearch/Search/Searcher.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"

LeafQuery*
LeafQuery_new(const CharBuf *field, const CharBuf *text)
{
    LeafQuery *self = (LeafQuery*)VTable_Make_Obj(LEAFQUERY);
    return LeafQuery_init(self, field, text);
}

LeafQuery*
LeafQuery_init(LeafQuery *self, const CharBuf *field, const CharBuf *text)
{
    Query_init((Query*)self, 1.0f);
    self->field       = field ? CB_Clone(field) : NULL;
    self->text        = CB_Clone(text);
    return self;
}

void
LeafQuery_destroy(LeafQuery *self)
{
    DECREF(self->field);
    DECREF(self->text);
    SUPER_DESTROY(self, LEAFQUERY);
}

CharBuf* 
LeafQuery_get_field(LeafQuery *self) { return self->field; }
CharBuf* 
LeafQuery_get_text(LeafQuery *self)  { return self->text; }

bool_t
LeafQuery_equals(LeafQuery *self, Obj *other)
{
    LeafQuery *evil_twin = (LeafQuery*)other;
    if (evil_twin == self) return true;
    if (!Obj_Is_A(other, LEAFQUERY)) return false;
    if (self->boost != evil_twin->boost) return false;
    if (!!self->field ^ !!evil_twin->field) return false;
    if (self->field) {
        if (!CB_Equals(self->field, (Obj*)evil_twin->field)) return false;
    }
    if (!CB_Equals(self->text, (Obj*)evil_twin->text)) return false;
    return true;
}

CharBuf*
LeafQuery_to_string(LeafQuery *self)
{
    if (self->field) {
        return CB_newf("%o:%o", self->field, self->text);
    }
    else {
        return CB_Clone(self->text);
    }
}

void
LeafQuery_serialize(LeafQuery *self, OutStream *outstream)
{
    if (self->field) {
        OutStream_Write_U8(outstream, true);
        CB_Serialize(self->field, outstream);
    }
    else {
        OutStream_Write_U8(outstream, false);
    }
    CB_Serialize(self->text, outstream);
    OutStream_Write_F32(outstream, self->boost);
}

LeafQuery*
LeafQuery_deserialize(LeafQuery *self, InStream *instream)
{
    self = self ? self : (LeafQuery*)VTable_Make_Obj(LEAFQUERY);
    self->field = InStream_Read_U8(instream) 
                ? CB_deserialize(NULL, instream)
                : NULL;
    self->text  = CB_deserialize(NULL, instream);
    self->boost = InStream_Read_F32(instream);
    return self;
}

Compiler*
LeafQuery_make_compiler(LeafQuery *self, Searcher *searcher, float boost) 
{
    UNUSED_VAR(self);
    UNUSED_VAR(searcher);
    UNUSED_VAR(boost);
    THROW(ERR, "Can't Make_Compiler() from LeafQuery");
    UNREACHABLE_RETURN(Compiler*);
}

/* Copyright 2008-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

