#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Inverter.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/I32Array.h"
#include "KinoSearch/Util/Json.h"
#include "KinoSearch/Util/StringHelper.h"
#include "KinoSearch/Util/IndexFileNames.h"

Segment*
Seg_new(const CharBuf *name, Folder *folder)
{
    Segment *self = (Segment*)VTable_Make_Obj(&SEGMENT);
    return Seg_init(self, name, folder);
}

Segment*
Seg_init(Segment *self, const CharBuf *name, Folder *folder)
{
    /* Init. */
    self->metadata  = Hash_new(0);
    self->count     = 0;
    self->by_num    = VA_new(2);
    self->by_name   = Hash_new(0);

    /* Start field numbers at 1, not 0. */
    VA_Push(self->by_num, INCREF(&EMPTY));

    /* Assign. */
    self->folder   = (Folder*)INCREF(folder);
    self->name     = CB_Clone(name);

    /* Derive. */
    self->seg_num = IxFileNames_extract_gen(name);

    return self;
}

void
Seg_destroy(Segment *self)
{
    DECREF(self->name);
    DECREF(self->folder);
    DECREF(self->metadata);
    DECREF(self->by_name);
    DECREF(self->by_num);
    FREE_OBJ(self);
}

bool_t
Seg_read_file(Segment *self)
{
    CharBuf *filename = CB_newf("%o/segmeta.json", self->name);
    Hash    *metadata = (Hash*)Json_slurp_json(self->folder, filename);
    Hash    *my_metadata;

    /* Bail unless the segmeta file was read successfully. */
    DECREF(filename);
    if (!metadata) { return false; }
    ASSERT_IS_A(metadata, HASH);

    /* Grab metadata for the Segment object itself. */
    DECREF(self->metadata);
    self->metadata = metadata;
    my_metadata = (Hash*)ASSERT_IS_A(
        Hash_Fetch_Str(self->metadata, "segmeta", 7), HASH);

    /* Assign. */
    {
        Obj *count = Hash_Fetch_Str(my_metadata, "count", 5);
        if (!count) { count = Hash_Fetch_Str(my_metadata, "doc_count", 9); }
        if (!count) { THROW("Missing 'count'"); }
        else { self->count = (i32_t)Obj_To_I64(count); }
    }

    /* Get list of field nums. */
    {
        u32_t i;
        VArray *source_by_num = (VArray*)Hash_Fetch_Str(my_metadata, 
            "field_names", 11);
        u32_t num_fields = source_by_num ? VA_Get_Size(source_by_num) : 0;
        if (source_by_num == NULL) {
            THROW("Failed to extract 'field_names' from metadata");
        }

        /* Init. */
        DECREF(self->by_num);
        DECREF(self->by_name);
        self->by_num  = VA_new(num_fields);
        self->by_name = Hash_new(num_fields);

        /* Copy the list of fields from the source. */
        for (i = 0; i < num_fields; i++) {
            CharBuf *name = (CharBuf*)VA_Fetch(source_by_num, i);
            Seg_Add_Field(self, name);
        }
    }

    return true;
}

void
Seg_write_file(Segment *self)
{
    CharBuf *filename    = CB_newf("%o/segmeta.json", self->name);
    Hash    *my_metadata = Hash_new(16);

    /* Store metadata specific to this Segment object. */
    Hash_Store_Str(my_metadata, "count", 5, 
        (Obj*)CB_newf("%i32", (i32_t)self->count) );
    Hash_Store_Str(my_metadata, "name", 4, (Obj*)CB_Clone(self->name));
    Hash_Store_Str(my_metadata, "field_names", 11, INCREF(self->by_num));
    Hash_Store_Str(my_metadata, "format", 6, (Obj*)CB_newf("%i32", 1));
    Hash_Store_Str(self->metadata, "segmeta", 7, (Obj*)my_metadata);

    Json_spew_json((Obj*)self->metadata, self->folder, filename);
    DECREF(filename);
}

i32_t 
Seg_add_field(Segment *self, const CharBuf *field)
{
    Float64 *num = (Float64*)Hash_Fetch(self->by_name, (Obj*)field);
    if (num) {
        return (i32_t)Float64_Get_Value(num);
    }
    else {
        i32_t field_num = VA_Get_Size(self->by_num);
        Hash_Store(self->by_name, (Obj*)field, (Obj*)Float64_new(field_num));
        VA_Push(self->by_num, (Obj*)CB_Clone(field));
        return field_num;
    }
}

CharBuf*
Seg_get_name(Segment *self)               { return self->name; }
void
Seg_set_count(Segment *self, i32_t count) { self->count = count; }
i32_t
Seg_get_count(Segment *self)              { return self->count; }

i32_t
Seg_increment_count(Segment *self, i32_t increment) 
{ 
   self->count += increment;
   return self->count;
}

void
Seg_store_metadata(Segment *self, const CharBuf *key, Obj *value)
{
    if (Hash_Fetch(self->metadata, (Obj*)key)) {
        THROW("Metadata key '%o' already registered", key);
    }
    Hash_Store(self->metadata, (Obj*)key, value);
}

void
Seg_store_metadata_str(Segment *self, const char *key, size_t key_len, Obj *value)
{
    ZombieCharBuf k = ZCB_make_str((char*)key, key_len);
    Seg_store_metadata(self, (CharBuf*)&k, value);
}

Obj*
Seg_fetch_metadata(Segment *self, const CharBuf *key)
{
    return Hash_Fetch(self->metadata, (Obj*)key);
}

Obj*
Seg_fetch_metadata_str(Segment *self, const char *key, size_t len)
{
    return Hash_Fetch_Str(self->metadata, key, len);
}

Hash*
Seg_get_metadata(Segment *self) { return self->metadata; }
    
i32_t
Seg_compare_to(Segment *self, Obj *other)
{
    Segment *other_seg = (Segment*)other;
    return self->seg_num - other_seg->seg_num;
}

CharBuf*
Seg_field_name(Segment *self, i32_t field_num)
{
     return field_num 
        ? (CharBuf*)VA_Fetch(self->by_num, field_num)
        : NULL;
}

i32_t
Seg_field_num(Segment *self, const CharBuf *field)
{
    if (field == NULL) {
        return 0;
    }
    else {
        Float64 *num = (Float64*)Hash_Fetch(self->by_name, (Obj*)field);
        if (num == NULL)
            return 0;
        return (i32_t)Float64_Get_Value(num);
    }
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

