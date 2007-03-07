#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SEGINFO_VTABLE
#include "KinoSearch/Index/SegInfo.r"

#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Util/Int.r"
#include "KinoSearch/Util/IntMap.r"

SegInfo*
SegInfo_new(const ByteBuf *seg_name, Hash *fspecs, Hash *source_metadata)
{
    Hash   *seg_info_metadata = NULL;
    CREATE(self, SegInfo, SEGINFO);

    /* either assign or create metadata hash */
    if (source_metadata != NULL) {
        seg_info_metadata = (Hash*)Hash_Fetch(source_metadata, "seg_info", 8);
        REFCOUNT_INC(source_metadata);
        self->metadata = source_metadata;
    }
    else {
        self->metadata = Hash_new(0);
    }

    /* assign */
    self->seg_name  = BB_CLONE(seg_name);
    self->doc_count = seg_info_metadata == NULL
        ? 0
        : Hash_Fetch_I64(seg_info_metadata, "doc_count", 9);

    /* get list of field nums, either from metadata or fspecs hash */
    if (seg_info_metadata != NULL) {
        u32_t i;
        VArray *source_by_num = (VArray*)Hash_Fetch(seg_info_metadata, 
            "field_names", 11);
        if (source_by_num == NULL)
            CONFESS("Failed to extract 'field_names' from metadata");

        /* init */
        self->by_num  = VA_new(source_by_num->size);
        self->by_name = Hash_new(source_by_num->size);

        /* copy the list of fields from the source */
        for (i = 0; i < source_by_num->size; i++) {
            ByteBuf *name = (ByteBuf*)VA_Fetch(source_by_num, i);
            SegInfo_Add_Field(self, name);
        }
    }
    else if (fspecs != NULL) {
        ByteBuf *field_name;
        Obj *ignore;

        /* init */
        self->by_num  = VA_new(fspecs->size);
        self->by_name = Hash_new(fspecs->size);

        /* add all fields in the fspecs */
        Hash_Iter_Init(fspecs);
        while (Hash_Iter_Next(fspecs, &field_name, &ignore)) {
            SegInfo_Add_Field(self, field_name);
        }
    }
    else {
        CONFESS("Either metadata or fspecs must be non-NULL");
    }

    return self;
}

void
SegInfo_add_field(SegInfo *self, const ByteBuf *field_name)
{
    if ( (Hash_Fetch_BB(self->by_name, field_name)) == NULL) {
        Int *num = Int_new(self->by_num->size);
        ByteBuf *name_copy = BB_CLONE(field_name);
        VA_Push(self->by_num, (Obj*)name_copy);
        Hash_Store_BB(self->by_name, name_copy, (Obj*)num);
        REFCOUNT_DEC(name_copy);
        REFCOUNT_DEC(num);
    }
}

void
SegInfo_destroy(SegInfo *self)
{
    REFCOUNT_DEC(self->seg_name);
    REFCOUNT_DEC(self->metadata);
    REFCOUNT_DEC(self->by_name);
    REFCOUNT_DEC(self->by_num);
    free(self);
}

void
SegInfo_add_metadata(SegInfo *self, const char *key, size_t key_len,
                     Obj *value)
{
    Hash_Store(self->metadata, key, key_len, value);
}

Obj*
SegInfo_extract_metadata(SegInfo *self, const char *key, size_t key_len)
{
    Obj *retval = Hash_Fetch(self->metadata, key, key_len);
    if (retval == NULL)
        CONFESS("Failed to extract metadata for %s in segment %s", key,
            self->seg_name->ptr);
    return retval;
}

Hash*
SegInfo_get_metadata(SegInfo *self)
{
    Hash *seg_info_metadata = Hash_new(16);
    ByteBuf *seg_name_copy = BB_CLONE(self->seg_name);
    
    /* store metadata specific to this SegInfo object */
    Hash_Store_I64(seg_info_metadata, "doc_count", 9, (i64_t)self->doc_count);
    Hash_Store(seg_info_metadata, "seg_name", 8, (Obj*)seg_name_copy);
    Hash_Store(seg_info_metadata, "field_names", 11, (Obj*)self->by_num);
    Hash_Store(self->metadata, "seg_info", 8, (Obj*)seg_info_metadata);
    REFCOUNT_DEC(seg_name_copy);
    REFCOUNT_DEC(seg_info_metadata);

    return self->metadata;
}

ByteBuf empty_string = BYTEBUF_BLANK;

ByteBuf*
SegInfo_field_name(SegInfo *self, i32_t field_num)
{
    if (field_num == -1) {
        return &empty_string;
    }
    else {
         ByteBuf * field_name = (ByteBuf*)VA_Fetch(self->by_num, field_num);
         return field_name == NULL ? &empty_string : field_name;
    }
}

i32_t
SegInfo_field_num(SegInfo *self, const ByteBuf *field_name)
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

IntMap*
SegInfo_generate_field_num_map(SegInfo *self, SegInfo *other)
{
    IntMap *map = NULL;
    u32_t my_num_fields    = self->by_num->size;
    u32_t their_num_fields = other->by_num->size;
    bool_t must_build      = false;


    /* don't build the map unless field lists differ */
    if (their_num_fields != my_num_fields) {
        must_build = true;
    }
    else {
        u32_t i;
        VArray *my_by_num     = self->by_num;
        VArray *their_by_num  = other->by_num;
        for (i = 0; i < my_num_fields; i++) {
            ByteBuf *my_field_name = (ByteBuf*)VA_Fetch(my_by_num, i);
            ByteBuf *their_field_name = (ByteBuf*)VA_Fetch(their_by_num, i);
            if (!BB_Equals(my_field_name, (Obj*)their_field_name)) {
                must_build = true;
                break;
            }
        }
    }

    if (must_build) {
        u32_t i;
        i32_t *ints = MALLOCATE(their_num_fields, i32_t);

        /* map from other's fields to mine */
        for (i = 0; i < their_num_fields; i++) {
            ByteBuf *field_name = (ByteBuf*)VA_Fetch(other->by_num, i);
            const i32_t new_num = SegInfo_Field_Num(self, field_name);
            ints[i] = new_num;
        }

        map = IntMap_new(ints, their_num_fields);
    }

    return map;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

