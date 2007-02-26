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
    kino_u32_t refcount;
    struct kino_ByteBuf *path;
};

/* Given a filename, return an OutStream object.
 */
KINO_METHOD("Kino_Folder_Open_OutStream",
struct kino_OutStream*
kino_Folder_open_outstream(kino_Folder *self,  
                           const struct kino_ByteBuf *filename));

/* Given a filename, return an InStream object.
 */
KINO_METHOD("Kino_Folder_Open_InStream",
struct kino_InStream*
kino_Folder_open_instream(kino_Folder *self,  
                          const struct kino_ByteBuf *filename));

/* Return a list of all the files in the Folder.  The elements in the VArray
 * are all ByteBuf*.
 */
KINO_METHOD("Kino_Folder_List",
struct kino_VArray*
kino_Folder_list(kino_Folder *self));

/* Indicate whether the folder contains a file with the given filename.
 */
KINO_METHOD("Kino_Folder_File_Exists",
kino_bool_t
kino_Folder_file_exists(kino_Folder *self, 
                        const struct kino_ByteBuf *filename));

/* Rename a file.
 */
KINO_METHOD("Kino_Folder_Rename_File",
void
kino_Folder_rename_file(kino_Folder *self, 
                        const struct kino_ByteBuf *from,
                        const struct kino_ByteBuf *to));

/* Delete a file from the folder.
 */
KINO_METHOD("Kino_Folder_Delete_File",
void
kino_Folder_delete_file(kino_Folder *self, 
                        const struct kino_ByteBuf *filename));

/* Return a ByteBuf with the file's contents.  Only for small files, 
 * obviously.
 */
KINO_METHOD("Kino_Folder_Slurp_File",
struct kino_ByteBuf*
kino_Folder_slurp_file(kino_Folder *self, 
                       const struct kino_ByteBuf *filename));

/* Scan the folder contents and return the latest "generation" of a
 * filename.
 */
KINO_METHOD("Kino_Folder_Latest_Gen",
struct kino_ByteBuf*
kino_Folder_latest_gen(kino_Folder *self, 
                       const struct kino_ByteBuf *base, 
                       const struct kino_ByteBuf *ext));

/* Factory method for creating a KinoSearch::Store::Lock subclassed object.
 */
KINO_METHOD("Kino_Folder_Make_Lock",
struct kino_Lock*
kino_Folder_make_lock(kino_Folder *self, 
                      const struct kino_ByteBuf *lock_name,
                      const struct kino_ByteBuf *lock_id,
                      kino_i32_t timeout));

/* Create a Lock object and obtain a lock.  Run the function specified by the
 * [func] parameter, passing it [arg]. (If more than one arg is needed, pass a
 * struct pointer.)  Release the lock and destroy the Lock object.  
 */
KINO_METHOD("Kino_Folder_Run_Locked",
void
kino_Folder_run_locked(kino_Folder *self, 
                       const struct kino_ByteBuf *lock_name,
                       const struct kino_ByteBuf *lock_id,
                       kino_i32_t timeout, 
                       void(*func)(void *arg), 
                       void *arg));

/* Close the folder and release implementation-specific resources.
 */
KINO_METHOD("Kino_Folder_Close_F",
void
kino_Folder_close_f(kino_Folder *self));

KINO_END_CLASS

#endif /* H_KINO_FOLDER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

