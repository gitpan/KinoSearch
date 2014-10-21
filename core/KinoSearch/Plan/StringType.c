#define C_KINO_STRINGTYPE
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Plan/StringType.h"
#include "KinoSearch/Index/Posting/ScorePosting.h"
#include "KinoSearch/Index/Similarity.h"

StringType*
StringType_new()
{
    StringType *self = (StringType*)VTable_Make_Obj(STRINGTYPE);
    return StringType_init(self);
}

StringType*
StringType_init(StringType *self)
{
    return StringType_init2(self, 1.0, true, true, false);
}

StringType*
StringType_init2(StringType *self, float boost, bool_t indexed, 
                 bool_t stored, bool_t sortable)
{
    FType_init((FieldType*)self);
    self->boost      = boost;
    self->indexed    = indexed;
    self->stored     = stored;
    self->sortable   = sortable;
    return self;
}

bool_t
StringType_equals(StringType *self, Obj *other)
{
    StringType *evil_twin = (StringType*)other;
    if (evil_twin == self) return true;
    if (!FType_equals((FieldType*)self, other)) return false;
    return true;
}

Hash*
StringType_dump_for_schema(StringType *self) 
{
    Hash *dump = Hash_new(0);
    Hash_Store_Str(dump, "type", 4, (Obj*)CB_newf("string"));

    // Store attributes that override the defaults. 
    if (self->boost != 1.0) {
        Hash_Store_Str(dump, "boost", 5, (Obj*)CB_newf("%f64", self->boost));
    }
    if (!self->indexed) {
        Hash_Store_Str(dump, "indexed", 7, (Obj*)CB_newf("0"));
    }
    if (!self->stored) {
        Hash_Store_Str(dump, "stored", 6, (Obj*)CB_newf("0"));
    }
    if (self->sortable) {
        Hash_Store_Str(dump, "sortable", 8, (Obj*)CB_newf("1"));
    }

    return dump;
}

Hash*
StringType_dump(StringType *self)
{
    Hash *dump = StringType_Dump_For_Schema(self);
    Hash_Store_Str(dump, "_class", 6, 
        (Obj*)CB_Clone(StringType_Get_Class_Name(self)));
    DECREF(Hash_Delete_Str(dump, "type", 4));
    return dump;
}

StringType*
StringType_load(StringType *self, Obj *dump)
{
    Hash *source = (Hash*)CERTIFY(dump, HASH);
    CharBuf *class_name = (CharBuf*)Hash_Fetch_Str(source, "_class", 6);
    VTable *vtable 
        = (class_name != NULL && Obj_Is_A((Obj*)class_name, CHARBUF))
        ? VTable_singleton(class_name, NULL)
        : STRINGTYPE;
    StringType *loaded   = (StringType*)VTable_Make_Obj(vtable);
    Obj *boost_dump      = Hash_Fetch_Str(source, "boost", 5);
    Obj *indexed_dump    = Hash_Fetch_Str(source, "indexed", 7);
    Obj *stored_dump     = Hash_Fetch_Str(source, "stored", 6);
    Obj *sortable_dump   = Hash_Fetch_Str(source, "sortable", 8);
    UNUSED_VAR(self);

    StringType_init(loaded);
    if (boost_dump)    
        { loaded->boost    = (float)Obj_To_F64(boost_dump);     }
    if (indexed_dump)  
        { loaded->indexed  = (bool_t)Obj_To_I64(indexed_dump);  }
    if (stored_dump)   
        { loaded->stored   = (bool_t)Obj_To_I64(stored_dump);   }
    if (sortable_dump) 
        { loaded->sortable = (bool_t)Obj_To_I64(sortable_dump); }

    return loaded;
}

Similarity*
StringType_make_similarity(StringType *self)
{
    UNUSED_VAR(self);
    return Sim_new();
}

Posting*
StringType_make_posting(StringType *self, Similarity *similarity)
{
    if (similarity) {
        return (Posting*)ScorePost_new(similarity);
    }
    else {
        Similarity *sim = StringType_Make_Similarity(self);
        Posting *posting = (Posting*)ScorePost_new(sim);
        DECREF(sim);
        return posting;
    }
}

/* Copyright 2007-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

