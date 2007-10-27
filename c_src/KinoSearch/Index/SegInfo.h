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
    KINO_OBJ_MEMBER_VARS;
    struct kino_ByteBuf  *seg_name;
    chy_u32_t             doc_count;
    struct kino_Hash     *by_name; /* field numbers by name */
    struct kino_VArray   *by_num;  /* field names by num */
    struct kino_Hash     *metadata;
};

/* Constructor.  If [metadata] is null, default values will be used, 
 * otherwise values will be extracted.
 */
kino_SegInfo*
kino_SegInfo_new(const struct kino_ByteBuf *seg_name, 
                 struct kino_Hash *fspecs,
                 struct kino_Hash *metadata);

/* Attempt to add a field to the SegInfo.  If the field was already known,
 * nothing will happen.
 */
void
kino_SegInfo_add_field(kino_SegInfo *self, 
                       const struct kino_ByteBuf *field_name);
KINO_METHOD("Kino_SegInfo_Add_Field");

/* Store arbitrary data in the segment's metadata, to be serialized later. 
 * Callers should be very conservative about what they place here, since it is
 * a shared namespace.
 */
void
kino_SegInfo_add_metadata(kino_SegInfo *self, const char *key, size_t key_len,
                          kino_Obj *value);
KINO_METHOD("Kino_SegInfo_Add_Metadata");

/* Get the segment metadata, also cueing the SegInfo object itself to store
 * its own data.
 */
struct kino_Hash*
kino_SegInfo_get_metadata(kino_SegInfo *self);
KINO_METHOD("Kino_SegInfo_Get_Metadata");

/* Get a value from the segment metadata.  Throw an error if the key can't be
 * found (rather than return NULL).
 */
kino_Obj*
kino_SegInfo_extract_metadata(kino_SegInfo *self, const char *key, 
                              size_t key_len);
KINO_METHOD("Kino_SegInfo_Extract_Metadata");

/* Given a field number, return the name of its field, or NULL if the field
 * name can't be found.
 */
struct kino_ByteBuf*
kino_SegInfo_field_name(kino_SegInfo *self, chy_i32_t field_num);
KINO_METHOD("Kino_SegInfo_Field_Name");

/* Given a field name, return its field number for this segment (which may
 * differ from the number returned by other segments or by the Schema).
 * Return -1 if the field name can't be found.  
 */
chy_i32_t
kino_SegInfo_field_num(kino_SegInfo *self, 
                       const struct kino_ByteBuf *field_name);
KINO_METHOD("Kino_SegInfo_Field_Num");

void
kino_SegInfo_destroy(kino_SegInfo *self);
KINO_METHOD("Kino_SegInfo_Destroy");

KINO_END_CLASS

#endif /* H_KINO_SEGINFO */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

