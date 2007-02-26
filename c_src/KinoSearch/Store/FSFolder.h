#ifndef H_KINO_FSFOLDER
#define H_KINO_FSFOLDER 1

#include "KinoSearch/Store/Folder.r"

typedef struct kino_FSFolder kino_FSFolder;
typedef struct KINO_FSFOLDER_VTABLE KINO_FSFOLDER_VTABLE;

struct kino_Folder;
struct kino_ByteBuf;
struct kino_InStream;
struct kino_OutStream;
struct kino_VArray;

KINO_CLASS("KinoSearch::Store::FSFolder", "FSFolder", 
    "KinoSearch::Store::Folder");

struct kino_FSFolder {
    KINO_FSFOLDER_VTABLE *_;
    kino_u32_t refcount;
    KINO_FOLDER_MEMBER_VARS
};

KINO_FUNCTION(
kino_FSFolder*
kino_FSFolder_new(const struct kino_ByteBuf *path));

KINO_METHOD("Kino_FSFolder_Destroy",
void
kino_FSFolder_destroy(kino_FSFolder *self));

KINO_METHOD("Kino_FSFolder_Open_OutStream",
struct kino_OutStream*
kino_FSFolder_open_outstream(kino_FSFolder *self, 
                             const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_FSFolder_Open_InStream",
struct kino_InStream*
kino_FSFolder_open_instream(kino_FSFolder *self,   
                            const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_FSFolder_List",
struct kino_VArray*
kino_FSFolder_list(kino_FSFolder *self));

KINO_METHOD("Kino_FSFolder_File_Exists",
kino_bool_t
kino_FSFolder_file_exists(kino_FSFolder *self, 
                          const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_FSFolder_Rename_File",
void
kino_FSFolder_rename_file(kino_FSFolder *self, 
                          const struct kino_ByteBuf* from, 
                          const struct kino_ByteBuf *to));

KINO_METHOD("Kino_FSFolder_Delete_File",
void
kino_FSFolder_delete_file(kino_FSFolder *self, 
                          const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_FSFolder_Slurp_File",
struct kino_ByteBuf*
kino_FSFolder_slurp_file(kino_FSFolder *self, 
                         const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_FSFolder_Close_F",
void
kino_FSFolder_close_f(kino_FSFolder *self));

KINO_END_CLASS

#endif /* H_KINO_FSFOLDER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

