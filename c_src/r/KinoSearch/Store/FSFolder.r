/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_FSFOLDER
#define R_KINO_FSFOLDER 1

#include "KinoSearch/Store/FSFolder.h"

typedef void
(*kino_FSFolder_destroy_t)(kino_FSFolder *self);

typedef struct kino_OutStream*
(*kino_FSFolder_open_outstream_t)(kino_FSFolder *self, 
                             const struct kino_ByteBuf *filename);

typedef struct kino_InStream*
(*kino_FSFolder_open_instream_t)(kino_FSFolder *self,   
                            const struct kino_ByteBuf *filename);

typedef struct kino_VArray*
(*kino_FSFolder_list_t)(kino_FSFolder *self);

typedef kino_bool_t
(*kino_FSFolder_file_exists_t)(kino_FSFolder *self, 
                          const struct kino_ByteBuf *filename);

typedef void
(*kino_FSFolder_rename_file_t)(kino_FSFolder *self, 
                          const struct kino_ByteBuf* from, 
                          const struct kino_ByteBuf *to);

typedef void
(*kino_FSFolder_delete_file_t)(kino_FSFolder *self, 
                          const struct kino_ByteBuf *filename);

typedef struct kino_ByteBuf*
(*kino_FSFolder_slurp_file_t)(kino_FSFolder *self, 
                         const struct kino_ByteBuf *filename);

typedef void
(*kino_FSFolder_close_f_t)(kino_FSFolder *self);

#define Kino_FSFolder_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_FSFolder_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_FSFolder_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_FSFolder_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_FSFolder_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_FSFolder_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_FSFolder_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_FSFolder_Open_OutStream(_self, _arg1) \
    (_self)->_->open_outstream((kino_Folder*)_self, _arg1)

#define Kino_FSFolder_Open_InStream(_self, _arg1) \
    (_self)->_->open_instream((kino_Folder*)_self, _arg1)

#define Kino_FSFolder_List(_self) \
    (_self)->_->list((kino_Folder*)_self)

#define Kino_FSFolder_File_Exists(_self, _arg1) \
    (_self)->_->file_exists((kino_Folder*)_self, _arg1)

#define Kino_FSFolder_Rename_File(_self, _arg1, _arg2) \
    (_self)->_->rename_file((kino_Folder*)_self, _arg1, _arg2)

#define Kino_FSFolder_Delete_File(_self, _arg1) \
    (_self)->_->delete_file((kino_Folder*)_self, _arg1)

#define Kino_FSFolder_Slurp_File(_self, _arg1) \
    (_self)->_->slurp_file((kino_Folder*)_self, _arg1)

#define Kino_FSFolder_Latest_Gen(_self, _arg1, _arg2) \
    (_self)->_->latest_gen((kino_Folder*)_self, _arg1, _arg2)

#define Kino_FSFolder_Make_Lock(_self, _arg1, _arg2, _arg3) \
    (_self)->_->make_lock((kino_Folder*)_self, _arg1, _arg2, _arg3)

#define Kino_FSFolder_Run_Locked(_self, _arg1, _arg2, _arg3, _arg4, _arg5) \
    (_self)->_->run_locked((kino_Folder*)_self, _arg1, _arg2, _arg3, _arg4, _arg5)

#define Kino_FSFolder_Close_F(_self) \
    (_self)->_->close_f((kino_Folder*)_self)

struct KINO_FSFOLDER_VTABLE {
    KINO_OBJ_VTABLE *_;
    kino_u32_t refcount;
    KINO_OBJ_VTABLE *parent;
    const char *class_name;
    kino_Obj_clone_t clone;
    kino_Obj_destroy_t destroy;
    kino_Obj_equals_t equals;
    kino_Obj_hash_code_t hash_code;
    kino_Obj_is_a_t is_a;
    kino_Obj_to_string_t to_string;
    kino_Obj_serialize_t serialize;
    kino_Folder_open_outstream_t open_outstream;
    kino_Folder_open_instream_t open_instream;
    kino_Folder_list_t list;
    kino_Folder_file_exists_t file_exists;
    kino_Folder_rename_file_t rename_file;
    kino_Folder_delete_file_t delete_file;
    kino_Folder_slurp_file_t slurp_file;
    kino_Folder_latest_gen_t latest_gen;
    kino_Folder_make_lock_t make_lock;
    kino_Folder_run_locked_t run_locked;
    kino_Folder_close_f_t close_f;
};

extern KINO_FSFOLDER_VTABLE KINO_FSFOLDER;

#ifdef KINO_USE_SHORT_NAMES
  #define FSFolder kino_FSFolder
  #define FSFOLDER KINO_FSFOLDER
  #define FSFolder_new kino_FSFolder_new
  #define FSFolder_destroy kino_FSFolder_destroy
  #define FSFolder_open_outstream kino_FSFolder_open_outstream
  #define FSFolder_open_instream kino_FSFolder_open_instream
  #define FSFolder_list kino_FSFolder_list
  #define FSFolder_file_exists kino_FSFolder_file_exists
  #define FSFolder_rename_file kino_FSFolder_rename_file
  #define FSFolder_delete_file kino_FSFolder_delete_file
  #define FSFolder_slurp_file kino_FSFolder_slurp_file
  #define FSFolder_close_f kino_FSFolder_close_f
  #define FSFolder_Clone Kino_FSFolder_Clone
  #define FSFolder_Destroy Kino_FSFolder_Destroy
  #define FSFolder_Equals Kino_FSFolder_Equals
  #define FSFolder_Hash_Code Kino_FSFolder_Hash_Code
  #define FSFolder_Is_A Kino_FSFolder_Is_A
  #define FSFolder_To_String Kino_FSFolder_To_String
  #define FSFolder_Serialize Kino_FSFolder_Serialize
  #define FSFolder_Open_OutStream Kino_FSFolder_Open_OutStream
  #define FSFolder_Open_InStream Kino_FSFolder_Open_InStream
  #define FSFolder_List Kino_FSFolder_List
  #define FSFolder_File_Exists Kino_FSFolder_File_Exists
  #define FSFolder_Rename_File Kino_FSFolder_Rename_File
  #define FSFolder_Delete_File Kino_FSFolder_Delete_File
  #define FSFolder_Slurp_File Kino_FSFolder_Slurp_File
  #define FSFolder_Latest_Gen Kino_FSFolder_Latest_Gen
  #define FSFolder_Make_Lock Kino_FSFolder_Make_Lock
  #define FSFolder_Run_Locked Kino_FSFolder_Run_Locked
  #define FSFolder_Close_F Kino_FSFolder_Close_F
  #define FSFOLDER KINO_FSFOLDER
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_FSFOLDER_MEMBER_VARS \
    kino_u32_t  refcount; \
    struct kino_ByteBuf * path


#ifdef KINO_WANT_FSFOLDER_VTABLE
KINO_FSFOLDER_VTABLE KINO_FSFOLDER = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_FOLDER,
    "KinoSearch::Store::FSFolder",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_FSFolder_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_Folder_open_outstream_t)kino_FSFolder_open_outstream,
    (kino_Folder_open_instream_t)kino_FSFolder_open_instream,
    (kino_Folder_list_t)kino_FSFolder_list,
    (kino_Folder_file_exists_t)kino_FSFolder_file_exists,
    (kino_Folder_rename_file_t)kino_FSFolder_rename_file,
    (kino_Folder_delete_file_t)kino_FSFolder_delete_file,
    (kino_Folder_slurp_file_t)kino_FSFolder_slurp_file,
    (kino_Folder_latest_gen_t)kino_Folder_latest_gen,
    (kino_Folder_make_lock_t)kino_Folder_make_lock,
    (kino_Folder_run_locked_t)kino_Folder_run_locked,
    (kino_Folder_close_f_t)kino_FSFolder_close_f
};
#endif /* KINO_WANT_FSFOLDER_VTABLE */

#endif /* R_KINO_FSFOLDER */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */