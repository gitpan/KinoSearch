#ifndef H_KINO_COMPOUNDFILEREADER
#define H_KINO_COMPOUNDFILEREADER 1

#include "KinoSearch/Store/Folder.r"

struct kino_Hash;
struct kino_VArray;
struct kino_ByteBuf;
struct kino_SegInfo;
struct kino_InStream;
struct kino_InvIndex;

typedef struct kino_CompoundFileReader kino_CompoundFileReader;
typedef struct KINO_COMPOUNDFILEREADER_VTABLE KINO_COMPOUNDFILEREADER_VTABLE;

KINO_CLASS("KinoSearch::Index::CompoundFileReader", "CFReader", 
    "KinoSearch::Store::Folder"); /* note - subclasses Folder */

struct kino_CompoundFileReader {
    KINO_COMPOUNDFILEREADER_VTABLE *_;
    kino_u32_t refcount;
    KINO_FOLDER_MEMBER_VARS
    struct kino_InvIndex *invindex;
    struct kino_Folder   *folder;
    struct kino_SegInfo  *seg_info;
    struct kino_Hash     *entries;
    struct kino_InStream *instream;
};

KINO_FUNCTION(
kino_CompoundFileReader*
kino_CFReader_new(struct kino_InvIndex *invindex, 
                  struct kino_SegInfo *seg_info));

KINO_METHOD("Kino_CFReader_Open_InStream",
struct kino_InStream*
kino_CFReader_open_instream(kino_CompoundFileReader *self, 
                            const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_CFReader_Slurp_File",
struct kino_ByteBuf*
kino_CFReader_slurp_file(kino_CompoundFileReader *self,
                         const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_CFReader_File_Exists",
kino_bool_t
kino_CFReader_file_exists(kino_CompoundFileReader *self,
                          const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_CFReader_List",
struct kino_VArray*
kino_CFReader_list(kino_CompoundFileReader *self));

KINO_METHOD("Kino_CFReader_Close_F",
void
kino_CFReader_close_f(kino_CompoundFileReader *self));

KINO_METHOD("Kino_CFReader_Destroy",
void
kino_CFReader_destroy(kino_CompoundFileReader *self));

KINO_END_CLASS

#endif /* H_KINO_COMPOUNDFILEREADER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

