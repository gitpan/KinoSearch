#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/FieldType/FullTextType.h"
#include "KinoSearch/Analysis/Analyzer.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Posting/ScorePosting.h"
#include "KinoSearch/Search/Similarity.h"

FullTextType*
FullTextType_new(Analyzer *analyzer)
{
    FullTextType *self = (FullTextType*)VTable_Make_Obj(&FULLTEXTTYPE);
    return FullTextType_init(self, analyzer);
}

FullTextType*
FullTextType_init(FullTextType *self, Analyzer *analyzer)
{
    return FullTextType_init2(self, analyzer, 1.0, true, true, false);
}

FullTextType*
FullTextType_init2(FullTextType *self, Analyzer *analyzer, float boost,
                bool_t indexed, bool_t stored, bool_t highlightable)
{
    FType_init((FieldType*)self);

    /* Assign */
    self->boost         = boost;
    self->indexed       = indexed;
    self->stored        = stored;
    self->highlightable = highlightable;
    self->analyzer      = analyzer ? (Analyzer*)INCREF(analyzer) : NULL;

    return self;
}

void
FullTextType_destroy(FullTextType *self)
{
    DECREF(self->analyzer);
    SUPER_DESTROY(self, FULLTEXTTYPE);
}

bool_t
FullTextType_equals(FullTextType *self, Obj *other)
{
    FullTextType *evil_twin = (FullTextType*)other;
    if (evil_twin == self) return true;
    if (!OBJ_IS_A(evil_twin, FULLTEXTTYPE)) return false;
    if (!FType_equals((FieldType*)self, other)) return false;
    if (!!self->analyzer ^ !!evil_twin->analyzer) return false;
    if (!!self->highlightable != !!evil_twin->highlightable) return false;
    if (self->analyzer) {
        if (!Analyzer_Equals(self->analyzer, (Obj*)evil_twin->analyzer)) {
            return false;
        }
    }
    return true;
}

Hash*
FullTextType_dump_for_schema(FullTextType *self) 
{
    Hash *dump = Hash_new(0);
    Hash_Store_Str(dump, "type", 4, (Obj*)CB_newf("fulltext"));

    /* Store attributes that override the defaults. */
    if (self->boost != 1.0) {
        Hash_Store_Str(dump, "boost", 5, (Obj*)CB_newf("%f64", self->boost));
    }
    if (!self->indexed) {
        Hash_Store_Str(dump, "indexed", 7, (Obj*)CB_newf("0"));
    }
    if (!self->stored) {
        Hash_Store_Str(dump, "stored", 6, (Obj*)CB_newf("0"));
    }
    if (self->highlightable) {
        Hash_Store_Str(dump, "highlightable", 13, (Obj*)CB_newf("1"));
    }

    return dump;
}

Hash*
FullTextType_dump(FullTextType *self)
{
    Hash *dump = FullTextType_Dump_For_Schema(self);
    Hash_Store_Str(dump, "_class", 6, 
        (Obj*)CB_Clone(Obj_Get_Class_Name(self)));
    if (self->analyzer) {
        Hash_Store_Str(dump, "analyzer", 8, (Obj*)Analyzer_Dump(self->analyzer));
    }
    DECREF(Hash_Delete_Str(dump, "type", 4));
    
    return dump;
}

FullTextType*
FullTextType_load(FullTextType *self, Obj *dump)
{
    Hash *source = (Hash*)ASSERT_IS_A(dump, HASH);
    CharBuf *class_name = (CharBuf*)Hash_Fetch_Str(source, "_class", 6);
    VTable *vtable = (class_name != NULL && OBJ_IS_A(class_name, CHARBUF)) 
                   ? VTable_singleton(class_name, NULL)
                   : (VTable*)&FULLTEXTTYPE;
    FullTextType *loaded = (FullTextType*)VTable_Make_Obj(vtable);
    Hash *analyzer_dump  = (Hash*)Hash_Fetch_Str(source, "analyzer", 8);
    Analyzer *analyzer = NULL;
    Obj *boost_dump    = Hash_Fetch_Str(source, "boost", 5);
    Obj *indexed_dump  = Hash_Fetch_Str(source, "indexed", 7);
    Obj *stored_dump   = Hash_Fetch_Str(source, "stored", 6);
    Obj *hl_dump       = Hash_Fetch_Str(source, "highlightable", 13);
    UNUSED_VAR(self);

    /** Allow Schema to pollute the dump with an "analyzer" key that means
     * something else. */
    if (analyzer_dump && OBJ_IS_A(analyzer_dump, HASH)) {
        analyzer = (Analyzer*)ASSERT_IS_A(
            Obj_Load(analyzer_dump, (Obj*)analyzer_dump), ANALYZER);
    }

    FullTextType_init(loaded, analyzer);
    DECREF(analyzer);
    if (boost_dump)   { loaded->boost    = (float)Obj_To_F64(boost_dump);    }
    if (indexed_dump) { loaded->indexed  = (bool_t)Obj_To_I64(indexed_dump); }
    if (stored_dump)  { loaded->stored   = (bool_t)Obj_To_I64(stored_dump);  }
    if (hl_dump)      { loaded->highlightable = (bool_t)Obj_To_I64(hl_dump); }

    return loaded;
}

void
FullTextType_set_analyzer(FullTextType *self, Analyzer *analyzer) 
{
    DECREF(self->analyzer);
    self->analyzer = (Analyzer*)INCREF(analyzer);
}

void
FullTextType_set_highlightable(FullTextType *self, bool_t highlightable)
    { self->highlightable = highlightable; }

Analyzer*
FullTextType_get_analyzer(FullTextType *self)  { return self->analyzer; }
bool_t
FullTextType_highlightable(FullTextType *self) { return self->highlightable; }

void
FullTextType_set_sortable(FullTextType *self, bool_t sortable)
{
    UNUSED_VAR(self);
    if (sortable) { THROW("FullTextType fields can't be sortable"); }
}

Similarity*
FullTextType_make_similarity(FullTextType *self)
{
    UNUSED_VAR(self);
    return Sim_new();
}

Posting*
FullTextType_make_posting(FullTextType *self, Similarity *similarity)
{
    if (similarity) {
        return (Posting*)ScorePost_new(similarity);
    }
    else {
        Similarity *sim = FullTextType_Make_Similarity(self);
        Posting *posting = (Posting*)ScorePost_new(sim);
        DECREF(sim);
        return posting;
    }
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

