#define C_KINO_FULLTEXTTYPE
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Plan/FullTextType.h"
#include "KinoSearch/Analysis/Analyzer.h"
#include "KinoSearch/Index/Posting/ScorePosting.h"
#include "KinoSearch/Index/Similarity.h"

FullTextType*
FullTextType_new(Analyzer *analyzer)
{
    FullTextType *self = (FullTextType*)VTable_Make_Obj(FULLTEXTTYPE);
    return FullTextType_init(self, analyzer);
}

FullTextType*
FullTextType_init(FullTextType *self, Analyzer *analyzer)
{
    return FullTextType_init2(self, analyzer, 1.0, true, true, false, false);
}

FullTextType*
FullTextType_init2(FullTextType *self, Analyzer *analyzer, float boost,
                   bool_t indexed, bool_t stored, bool_t sortable, 
                   bool_t highlightable)
{
    FType_init((FieldType*)self);

    /* Assign */
    self->boost         = boost;
    self->indexed       = indexed;
    self->stored        = stored;
    self->sortable      = sortable;
    self->highlightable = highlightable;
    self->analyzer      = (Analyzer*)INCREF(analyzer);

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
    if (!Obj_Is_A(other, FULLTEXTTYPE)) return false;
    if (!FType_equals((FieldType*)self, other)) return false;
    if (!!self->sortable != !!evil_twin->sortable) return false;
    if (!!self->highlightable != !!evil_twin->highlightable) return false;
    if (!Analyzer_Equals(self->analyzer, (Obj*)evil_twin->analyzer)) {
        return false;
    }
    return true;
}

Hash*
FullTextType_dump_for_schema(FullTextType *self) 
{
    Hash *dump = Hash_new(0);
    Hash_Store_Str(dump, "type", 4, (Obj*)CB_newf("fulltext"));

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
        (Obj*)CB_Clone(FullTextType_Get_Class_Name(self)));
    Hash_Store_Str(dump, "analyzer", 8, 
        (Obj*)Analyzer_Dump(self->analyzer));
    DECREF(Hash_Delete_Str(dump, "type", 4));
    
    return dump;
}

FullTextType*
FullTextType_load(FullTextType *self, Obj *dump)
{
    UNUSED_VAR(self);
    Hash *source = (Hash*)CERTIFY(dump, HASH);
    CharBuf *class_name = (CharBuf*)Hash_Fetch_Str(source, "_class", 6);
    VTable *vtable 
        = (class_name != NULL && Obj_Is_A((Obj*)class_name, CHARBUF)) 
        ? VTable_singleton(class_name, NULL)
        : FULLTEXTTYPE;
    FullTextType *loaded = (FullTextType*)VTable_Make_Obj(vtable);

    // Extract boost.
    Obj *boost_dump = Hash_Fetch_Str(source, "boost", 5);
    float boost = boost_dump ? (float)Obj_To_F64(boost_dump) : 1.0f;

    // Find boolean properties.
    Obj *indexed_dump = Hash_Fetch_Str(source, "indexed", 7);
    Obj *stored_dump  = Hash_Fetch_Str(source, "stored", 6);
    Obj *sort_dump    = Hash_Fetch_Str(source, "sortable", 8);
    Obj *hl_dump      = Hash_Fetch_Str(source, "highlightable", 13);
    bool_t indexed  = indexed_dump ? (bool_t)Obj_To_I64(indexed_dump) : true;
    bool_t stored   = stored_dump  ? (bool_t)Obj_To_I64(stored_dump)  : true;
    bool_t sortable = sort_dump    ? (bool_t)Obj_To_I64(sort_dump)    : false;
    bool_t hl       = hl_dump      ? (bool_t)Obj_To_I64(hl_dump)      : false;

    // Extract an Analyzer.  
    Obj *analyzer_dump = Hash_Fetch_Str(source, "analyzer", 8);
    Analyzer *analyzer = NULL;
    if (analyzer_dump) {
        if (Obj_Is_A(analyzer_dump, ANALYZER)) {
            // Schema munged the dump and installed a shared analyzer.
            analyzer = (Analyzer*)INCREF(analyzer_dump);
        }
        else if (Obj_Is_A((Obj*)analyzer_dump, HASH)) {
            analyzer = (Analyzer*)Obj_Load(analyzer_dump, analyzer_dump);
        }
    }
    CERTIFY(analyzer, ANALYZER);

    FullTextType_init(loaded, analyzer);
    DECREF(analyzer);
    if (boost_dump)   { loaded->boost         = boost;    }
    if (indexed_dump) { loaded->indexed       = indexed;  }
    if (stored_dump)  { loaded->stored        = stored;   }
    if (sort_dump)    { loaded->sortable      = sortable; }
    if (hl_dump)      { loaded->highlightable = hl;       }

    return loaded;
}

void
FullTextType_set_highlightable(FullTextType *self, bool_t highlightable)
    { self->highlightable = highlightable; }

Analyzer*
FullTextType_get_analyzer(FullTextType *self)  { return self->analyzer; }
bool_t
FullTextType_highlightable(FullTextType *self) { return self->highlightable; }

Similarity*
FullTextType_make_similarity(FullTextType *self)
{
    UNUSED_VAR(self);
    return Sim_new();
}

/* Copyright 2007-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

