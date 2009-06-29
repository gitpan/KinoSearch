#include <string.h>
#include <ctype.h>
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Schema.h"
#include "KinoSearch/Analysis/Analyzer.h"
#include "KinoSearch/Architecture.h"
#include "KinoSearch/Posting.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/FieldType/BlobType.h"
#include "KinoSearch/FieldType/NumericType.h"
#include "KinoSearch/FieldType/StringType.h"
#include "KinoSearch/FieldType/FullTextType.h"
#include "KinoSearch/Obj.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/Json.h"

/* Scan the array to see if an object testing as Equal is present.  If not,
 * push the elem onto the end of the array. */
static void
S_add_unique(VArray *array, Obj *elem);

static void
S_add_text_field(Schema *self, const CharBuf *field, FieldType *type);
static void
S_add_string_field(Schema *self, const CharBuf *field, FieldType *type);
static void
S_add_blob_field(Schema *self, const CharBuf *field, FieldType *type);
static void
S_add_numeric_field(Schema *self, const CharBuf *field, FieldType *type);

Schema*
Schema_init(Schema *self)
{
    /* Init. */
    self->analyzers      = Hash_new(0);
    self->types          = Hash_new(0);
    self->sims           = Hash_new(0);
    self->postings       = Hash_new(0);
    self->uniq_analyzers = VA_new(2);
    VA_Resize(self->uniq_analyzers, 1);

    /* Assign. */
    self->arch = Schema_Architecture(self);
    self->sim  = Arch_Make_Similarity(self->arch);

    return self;
}

void
Schema_destroy(Schema *self) 
{
    DECREF(self->arch);
    DECREF(self->analyzers);
    DECREF(self->uniq_analyzers);
    DECREF(self->types);
    DECREF(self->postings);
    DECREF(self->sims);
    DECREF(self->sim);
    FREE_OBJ(self);
}

static void
S_add_unique(VArray *array, Obj *elem)
{
    u32_t i, max;
    if (!elem) { return; }
    for (i = 0, max = VA_Get_Size(array); i < max; i++) {
        Obj *candidate = VA_Fetch(array, i);
        if (!candidate) { continue; }
        if (elem == candidate) { return; }
        if (Obj_Equals(elem, candidate)) { return; }
    }
    VA_Push(array, INCREF(elem));
}

bool_t
Schema_equals(Schema *self, Obj *other)
{
    Schema *evil_twin = (Schema*)other;
    if (evil_twin == self) return true;
    if (!OBJ_IS_A(evil_twin, SCHEMA)) return false;
    if (!Arch_Equals(self->arch, (Obj*)evil_twin->arch)) return false;
    if (!Sim_Equals(self->sim, (Obj*)evil_twin->sim)) return false;
    if (!Hash_Equals(self->types, (Obj*)evil_twin->types)) return false;
    return true;
}

Architecture*
Schema_architecture(Schema *self)
{
    UNUSED_VAR(self);
    return Arch_new();
}

void
Schema_spec_field(Schema *self, const CharBuf *field, FieldType *type)
{
    FieldType *existing  = Schema_Fetch_Type(self, field);

    /* If the field already has an association, verify pairing and return. */
    if (existing) {
        if (FType_Equals(type, (Obj*)existing)) { return; }
        else { THROW(  "'%o' assigned conflicting FieldType", field); }
    }

    if (OBJ_IS_A(type, FULLTEXTTYPE)) {
        S_add_text_field(self, field, type);
    }
    else if (OBJ_IS_A(type, STRINGTYPE)) {
        S_add_string_field(self, field, type);
    }
    else if (OBJ_IS_A(type, BLOBTYPE)) {
        S_add_blob_field(self, field, type);
    }
    else if (OBJ_IS_A(type, NUMERICTYPE)) {
        S_add_numeric_field(self, field, type);
    }
    else {
        THROW("Unrecognized field type: '%o'", type);
    }
}

static void
S_add_text_field(Schema *self, const CharBuf *field, FieldType *type)
{
    FullTextType *fttype = (FullTextType*)ASSERT_IS_A(type, FULLTEXTTYPE);
    Similarity   *sim       = FullTextType_Make_Similarity(fttype);
    Posting      *posting   = FullTextType_Make_Posting(fttype, sim);
    Analyzer     *analyzer  = FullTextType_Get_Analyzer(fttype);

    /* Cache helpers. */
    Hash_Store(self->sims, (Obj*)field, (Obj*)sim);
    Hash_Store(self->postings, (Obj*)field, (Obj*)posting);
    Hash_Store(self->analyzers, (Obj*)field, INCREF(analyzer));
    S_add_unique(self->uniq_analyzers, (Obj*)analyzer);

    /* Store FieldType. */
    Hash_Store(self->types, (Obj*)field, INCREF(type));
}

static void
S_add_string_field(Schema *self, const CharBuf *field, FieldType *type)
{
    StringType *string_type = (StringType*)ASSERT_IS_A(type, STRINGTYPE);
    Similarity *sim         = StringType_Make_Similarity(string_type);
    Posting    *posting     = StringType_Make_Posting(string_type, sim);

    /* Cache helpers. */
    Hash_Store(self->sims, (Obj*)field, (Obj*)sim);
    Hash_Store(self->postings, (Obj*)field, (Obj*)posting);

    /* Store FieldType. */
    Hash_Store(self->types, (Obj*)field, INCREF(type));
}

static void
S_add_blob_field(Schema *self, const CharBuf *field, FieldType *type)
{
    BlobType *blob_type = (BlobType*)ASSERT_IS_A(type, BLOBTYPE);
    Hash_Store(self->types, (Obj*)field, INCREF(blob_type));
}

static void
S_add_numeric_field(Schema *self, const CharBuf *field, FieldType *type)
{
    NumericType *num_type = (NumericType*)ASSERT_IS_A(type, NUMERICTYPE);
    Hash_Store(self->types, (Obj*)field, INCREF(num_type));
}

FieldType*
Schema_fetch_type(Schema *self, const CharBuf *field)
{
    return (FieldType*)Hash_Fetch(self->types, (Obj*)field);
}

Analyzer*
Schema_fetch_analyzer(Schema *self, const CharBuf *field)
{
    return field
        ? (Analyzer*)Hash_Fetch(self->analyzers, (Obj*)field)
        : NULL;
}

Similarity*
Schema_fetch_sim(Schema *self, const CharBuf *field)
{
    Similarity *sim = NULL;
    if (field != NULL) {
        sim = (Similarity*)Hash_Fetch(self->sims, (Obj*)field);
    }        
    return sim;
}

Posting*
Schema_fetch_posting(Schema *self, const CharBuf *field)
{
    if (field == NULL) {
        return NULL;
    }
    else {
        return (Posting*)Hash_Fetch(self->postings, (Obj*)field);
    }
}

u32_t
Schema_num_fields(Schema *self)
{
    return VA_Get_Size(self->types);
}

Architecture*
Schema_get_architecture(Schema *self) { return self->arch; }
Similarity*
Schema_get_similarity(Schema *self)   { return self->sim; }

VArray*
Schema_all_fields(Schema *self)
{
    return Hash_Keys(self->types);
}

u32_t
S_find_in_array(VArray *array, Obj *obj)
{
    u32_t i, max;
    for (i = 0, max = VA_Get_Size(array); i < max; i++) {
        Obj *candidate = VA_Fetch(array, i);
        if (obj == NULL && candidate == NULL) {
            return i;
        }
        else if (obj != NULL && candidate != NULL) {
            if (Obj_Equals(obj, candidate)) {
                return i;
            }
        }
    }
    THROW("Couldn't find match for %o", obj);
    UNREACHABLE_RETURN(u32_t);
}

Hash*
Schema_dump(Schema *self)
{
    Hash *dump = Hash_new(0);
    Hash *type_dumps = Hash_new(Hash_Get_Size(self->types));
    CharBuf *field;
    FieldType *type;

    /* Record class name, store dumps of unique Analyzers. */
    Hash_Store_Str(dump, "_class", 6, 
        (Obj*)CB_Clone(Obj_Get_Class_Name(self)));
    Hash_Store_Str(dump, "analyzers", 9, (Obj*)VA_Dump(self->uniq_analyzers));

    /* Dump FieldTypes. */
    Hash_Store_Str(dump, "fields", 6, (Obj*)type_dumps);
    Hash_Iter_Init(self->types);
    while (Hash_Iter_Next(self->types, (Obj**)&field, (Obj**)&type)) {
        VTable *type_vtable = FType_Get_VTable(type);

        /* Dump known types to simplified format. */
        if (type_vtable == (VTable*)&FULLTEXTTYPE) {
            FullTextType *fttype = (FullTextType*)type;
            Hash *type_dump = FullTextType_Dump_For_Schema(type);
            Analyzer *analyzer = FullTextType_Get_Analyzer(fttype);
            u32_t tick = S_find_in_array(self->uniq_analyzers, (Obj*)analyzer);

            /* Store the tick which references a unique analyzer. */
            Hash_Store_Str(type_dump, "analyzer", 8, 
                (Obj*)CB_newf("%u32", tick));

            Hash_Store(type_dumps, (Obj*)field, (Obj*)type_dump);
        }
        else if (   type_vtable == (VTable*)&STRINGTYPE
                 || type_vtable == (VTable*)&BLOBTYPE
        ) {
            Hash *type_dump = FType_Dump_For_Schema(type);
            Hash_Store(type_dumps, (Obj*)field, (Obj*)type_dump);
        }
        /* Unknown FieldType type, so punt. */
        else {
            Hash_Store(type_dumps, (Obj*)field, FType_Dump(type));
        }
    }

    return dump;
}

Schema*
Schema_load(Schema *self, Obj *dump)
{
    Hash *source = (Hash*)ASSERT_IS_A(dump, HASH);
    CharBuf *class_name = (CharBuf*)ASSERT_IS_A(
        Hash_Fetch_Str(source, "_class", 6), CHARBUF);
    VTable *vtable = VTable_singleton(class_name, NULL);
    Schema *loaded = (Schema*)VTable_Make_Obj(vtable);
    Hash *type_dumps = (Hash*)ASSERT_IS_A(
        Hash_Fetch_Str(source, "fields", 6), HASH);
    VArray *analyzer_dumps = (VArray*)ASSERT_IS_A(
        Hash_Fetch_Str(source, "analyzers", 9), VARRAY);
    VArray *analyzers 
        = (VArray*)VA_Load(analyzer_dumps, (Obj*)analyzer_dumps);
    CharBuf *field;
    Hash    *type_dump;
    UNUSED_VAR(self);

    /* Start with a blank Schema. */
    Schema_init(loaded);
    VA_Grow(loaded->uniq_analyzers, VA_Get_Size(analyzers));

    Hash_Iter_Init(type_dumps);
    while (Hash_Iter_Next(type_dumps, (Obj**)&field, (Obj**)&type_dump)) {
        CharBuf *type_str;
        ASSERT_IS_A(type_dump, HASH);
        type_str = (CharBuf*)Hash_Fetch_Str(type_dump, "type", 4);
        if (type_str) {
            if (CB_Equals_Str(type_str, "fulltext", 8)) {
                FullTextType *type = (FullTextType*)VTable_Load_Obj(
                    &FULLTEXTTYPE, (Obj*)type_dump);
                Obj *tick = ASSERT_IS_A(
                    Hash_Fetch_Str(type_dump, "analyzer", 8), OBJ);
                Analyzer *analyzer 
                    = (Analyzer*)VA_Fetch(analyzers, (u32_t)Obj_To_I64(tick));
                if (!analyzer) { 
                    THROW("Can't find analyzer for '%o'", field);
                }
                FullTextType_Set_Analyzer(type, analyzer);
                Schema_Spec_Field(loaded, field, (FieldType*)type);
                DECREF(type);
            }
            else if (CB_Equals_Str(type_str, "string", 6)) {
                StringType *type = (StringType*)VTable_Load_Obj(
                    &STRINGTYPE, (Obj*)type_dump);
                Schema_Spec_Field(loaded, field, (FieldType*)type);
                DECREF(type);
            }
            else if (CB_Equals_Str(type_str, "blob", 4)) {
                BlobType *type = (BlobType*)VTable_Load_Obj(
                    &BLOBTYPE, (Obj*)type_dump);
                Schema_Spec_Field(loaded, field, (FieldType*)type);
                DECREF(type);
            }
            else if (CB_Equals_Str(type_str, "i32_t", 5)) {
                Int32Type *type = (Int32Type*)VTable_Load_Obj(
                    &INT32TYPE, (Obj*)type_dump);
                Schema_Spec_Field(loaded, field, (FieldType*)type);
                DECREF(type);
            }
            else if (CB_Equals_Str(type_str, "i64_t", 5)) {
                Int64Type *type = (Int64Type*)VTable_Load_Obj(
                    &INT64TYPE, (Obj*)type_dump);
                Schema_Spec_Field(loaded, field, (FieldType*)type);
                DECREF(type);
            }
            else if (CB_Equals_Str(type_str, "f32_t", 5)) {
                Float32Type *type = (Float32Type*)VTable_Load_Obj(
                    &FLOAT32TYPE, (Obj*)type_dump);
                Schema_Spec_Field(loaded, field, (FieldType*)type);
                DECREF(type);
            }
            else if (CB_Equals_Str(type_str, "f64_t", 5)) {
                Float64Type *type = (Float64Type*)VTable_Load_Obj(
                    &FLOAT64TYPE, (Obj*)type_dump);
                Schema_Spec_Field(loaded, field, (FieldType*)type);
                DECREF(type);
            }
            else {
                THROW("Unknown type '%o' for field '%o'", type_str, field);
            }
         }
        else {
            FieldType *type 
                = (FieldType*)Obj_Load(type_dump, (Obj*)type_dump);
            Schema_Spec_Field(loaded, field, type);
            DECREF(type);
        }
    }

    DECREF(analyzers);

    return loaded;
}

void
Schema_eat(Schema *self, Schema *other)
{
    if (!Schema_Is_A(self, Obj_Get_VTable(other))) {
        THROW("%o not a descendent of %o", Schema_Get_Class_Name(self),
            Schema_Get_Class_Name(other));
    }
    else {
        CharBuf *field;
        FieldType *type;
        Hash_Iter_Init(other->types);
        while (Hash_Iter_Next(other->types, (Obj**)&field, (Obj**)&type)) {
            Schema_Spec_Field(self, field, type);
        }
    }
}

void
Schema_write(Schema *self, Folder *folder, const CharBuf *filename)
{
    Hash *dump = Schema_Dump(self);
    static ZombieCharBuf schema_temp = ZCB_LITERAL("schema.temp");
    Folder_Delete(folder, (CharBuf*)&schema_temp); /* Just in case. */
    Json_spew_json((Obj*)dump, folder, (CharBuf*)&schema_temp);
    Folder_Rename(folder, (CharBuf*)&schema_temp, filename);
    DECREF(dump);
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

