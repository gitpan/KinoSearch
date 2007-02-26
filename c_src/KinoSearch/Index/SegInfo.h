#ifndef H_KINO_SEGINFO
#define H_KINO_SEGINFO 1

#include "KinoSearch/Util/Obj.r"

struct kino_ByteBuf;
struct kino_Hash;
struct kino_VArray;
struct kino_IntMap;

typedef struct kino_SegInfo kino_SegInfo;
typedef struct KINO_SEGINFO_VTABLE KINO_SEGINFO_VTABLE;

KINO_FINAL_CLASS("KinoSearch::Index::SegInfo", "SegInfo", 
    "KinoSearch::Util::Obj");

struct kino_SegInfo {
    KINO_SEGINFO_VTABLE *_;
    kino_u32_t refcount;
    struct kino_ByteBuf  *seg_name;
    kino_u32_t            doc_count;
    struct kino_Hash     *by_name; /* field numbers by name */
    struct kino_VArray   *by_num;  /* field names by num */
    struct kino_Hash     *metadata;
};

/* Constructor.  If [metadata] is null, default values will be used, other
 * wise values will be extracted.
 */
KINO_FUNCTION(
kino_SegInfo*
kino_SegInfo_new(const struct kino_ByteBuf *seg_name, 
                 struct kino_Hash *fspecs,
                 struct kino_Hash *metadata));

/* Store arbitrary data in the segment's metadata, to be serialized later. 
 * Callers should be very conservative about what they place here, since it is
 * a shared namespace.
 */
KINO_METHOD("Kino_SegInfo_Add_Metadata",
void
kino_SegInfo_add_metadata(kino_SegInfo *self, const char *key, size_t key_len,
                          kino_Obj *value));

/* Get the segment metadata, also cueing the SegInfo object itself to store
 * its own data.
 */
KINO_METHOD("Kino_SegInfo_Get_Metadata",
struct kino_Hash*
kino_SegInfo_get_metadata(kino_SegInfo *self));

/* Get a value from the segment metadata.  Throw an error if the key can't be
 * found (rather than return NULL).
 */
KINO_METHOD("Kino_SegInfo_Extract_Metadata",
kino_Obj*
kino_SegInfo_extract_metadata(kino_SegInfo *self, const char *key, 
                              size_t key_len));

/* Given a field number, return the name of its field, or NULL if the field
 * name can't be found.
 */
KINO_METHOD("Kino_SegInfo_Field_Name",
struct kino_ByteBuf*
kino_SegInfo_field_name(kino_SegInfo *self, kino_i32_t field_num));

/* Given a field name, return its field number for this segment.  Return -1 if
 * the field name can't be found.
 */
KINO_METHOD("Kino_SegInfo_Field_Num",
kino_i32_t
kino_SegInfo_field_num(kino_SegInfo *self, 
                       const struct kino_ByteBuf *field_name));

/* If two SegInfo objects have sets of fields which differ, return a mapping
 * from the field numbers of [other] to the field numbers of [self].  If the
 * field sets are identical, return NULL.
 */
KINO_METHOD("Kino_SegInfo_Generate_Field_Num_Map",
struct kino_IntMap*
kino_SegInfo_generate_field_num_map(kino_SegInfo *self, kino_SegInfo *other));

KINO_METHOD("Kino_SegInfo_Destroy",
void
kino_SegInfo_destroy(kino_SegInfo *self));

KINO_END_CLASS

#endif /* H_KINO_SEGINFO */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

