#ifndef H_KINO_FOLDER
#define H_KINO_FOLDER 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_Folder kino_Folder;
typedef struct KINO_FOLDER_VTABLE KINO_FOLDER_VTABLE;

struct kino_InStream;
struct kino_OutStream;
struct kino_Lock;
struct kino_VArray;
struct kino_ByteBuf;

KINO_CLASS("KinoSearch::Store::Folder", "Folder", "KinoSearch::Util::Obj");

struct kino_Folder {
    KINO_FOLDER_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_ByteBuf *path;
};

/* Given a filename, return an OutStream object.
 */
struct kino_OutStream*
kino_Folder_open_outstream(kino_Folder *self,  
                           const struct kino_ByteBuf *filename);
KINO_METHOD("Kino_Folder_Open_OutStream");

/* Like Folder_Open_OutStream, but won't clobber an existing file and returns
 * NULL rather than throwing an exception.
 */
struct kino_OutStream*
kino_Folder_safe_open_outstream(kino_Folder *self,  
                                const struct kino_ByteBuf *filename);
KINO_METHOD("Kino_Folder_Safe_Open_OutStream");

/* Given a filename, return an InStream object.
 */
struct kino_InStream*
kino_Folder_open_instream(kino_Folder *self,  
                          const struct kino_ByteBuf *filename);
KINO_METHOD("Kino_Folder_Open_InStream");

/* Return a list of all the files in the Folder.  The elements in the VArray
 * are all ByteBuf*.
 */
struct kino_VArray*
kino_Folder_list(kino_Folder *self);
KINO_METHOD("Kino_Folder_List");

/* Indicate whether the folder contains a file with the given filename.
 */
chy_bool_t
kino_Folder_file_exists(kino_Folder *self, 
                        const struct kino_ByteBuf *filename);
KINO_METHOD("Kino_Folder_File_Exists");

/* Rename a file.
 */
void
kino_Folder_rename_file(kino_Folder *self, 
                        const struct kino_ByteBuf *from,
                        const struct kino_ByteBuf *to);
KINO_METHOD("Kino_Folder_Rename_File");

/* Delete a file from the folder.
 */
void
kino_Folder_delete_file(kino_Folder *self, 
                        const struct kino_ByteBuf *filename);
KINO_METHOD("Kino_Folder_Delete_File");

/* Return a ByteBuf with the file's contents.  Only for small files, 
 * obviously.
 */
struct kino_ByteBuf*
kino_Folder_slurp_file(kino_Folder *self, 
                       const struct kino_ByteBuf *filename);
KINO_METHOD("Kino_Folder_Slurp_File");

/* Scan the folder contents and return the latest "generation" of a
 * filename.
 */
struct kino_ByteBuf*
kino_Folder_latest_gen(kino_Folder *self, 
                       const struct kino_ByteBuf *base, 
                       const struct kino_ByteBuf *ext);
KINO_METHOD("Kino_Folder_Latest_Gen");

/* Close the folder and release implementation-specific resources.
 */
void
kino_Folder_close_f(kino_Folder *self);
KINO_METHOD("Kino_Folder_Close_F");

KINO_END_CLASS

#endif /* H_KINO_FOLDER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

