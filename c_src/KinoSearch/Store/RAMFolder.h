#ifndef H_KINO_RAMFOLDER
#define H_KINO_RAMFOLDER 1

#include "KinoSearch/Store/Folder.r"

typedef struct kino_RAMFolder kino_RAMFolder;
typedef struct KINO_RAMFOLDER_VTABLE KINO_RAMFOLDER_VTABLE;

struct kino_Folder;
struct kino_Hash;

KINO_CLASS("KinoSearch::Store::RAMFolder", "RAMFolder", 
    "KinoSearch::Store::Folder");

struct kino_RAMFolder {
    KINO_RAMFOLDER_VTABLE *_;
    KINO_FOLDER_MEMBER_VARS;
    struct kino_Hash *ram_files;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_RAMFolder*
kino_RAMFolder_new(const struct kino_ByteBuf *path));

KINO_METHOD("Kino_RAMFolder_Destroy",
void
kino_RAMFolder_destroy(kino_RAMFolder *self));

KINO_METHOD("Kino_RAMFolder_Open_OutStream",
struct kino_OutStream*
kino_RAMFolder_open_outstream(kino_RAMFolder *self, 
                              const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_RAMFolder_Open_InStream",
struct kino_InStream*
kino_RAMFolder_open_instream(kino_RAMFolder *self,   
                             const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_RAMFolder_List",
struct kino_VArray*
kino_RAMFolder_list(kino_RAMFolder *self));

KINO_METHOD("Kino_RAMFolder_File_Exists",
kino_bool_t
kino_RAMFolder_file_exists(kino_RAMFolder *self, 
                           const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_RAMFolder_Rename_File",
void
kino_RAMFolder_rename_file(kino_RAMFolder *self, 
                           const struct kino_ByteBuf* from, 
                           const struct kino_ByteBuf *to));

KINO_METHOD("Kino_RAMFolder_Delete_File",
void
kino_RAMFolder_delete_file(kino_RAMFolder *self, 
                           const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_RAMFolder_Slurp_File",
struct kino_ByteBuf*
kino_RAMFolder_slurp_file(kino_RAMFolder *self, 
                          const struct kino_ByteBuf *filename));

KINO_METHOD("Kino_RAMFolder_Close_F",
void
kino_RAMFolder_close_f(kino_RAMFolder *self));

KINO_END_CLASS

#endif /* H_KINO_RAMFOLDER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

