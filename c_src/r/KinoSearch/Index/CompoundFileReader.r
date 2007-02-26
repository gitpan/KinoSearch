/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_CFREADER
#define R_KINO_CFREADER 1

#include "KinoSearch/Index/CompoundFileReader.h"

typedef void
(*kino_CFReader_destroy_t)(kino_CompoundFileReader *self);

typedef struct kino_InStream*
(*kino_CFReader_open_instream_t)(kino_CompoundFileReader *self, 
                            const struct kino_ByteBuf *filename);

typedef struct kino_VArray*
(*kino_CFReader_list_t)(kino_CompoundFileReader *self);

typedef kino_bool_t
(*kino_CFReader_file_exists_t)(kino_CompoundFileReader *self,
                          const struct kino_ByteBuf *filename);

typedef struct kino_ByteBuf*
(*kino_CFReader_slurp_file_t)(kino_CompoundFileReader *self,
                         const struct kino_ByteBuf *filename);

typedef void
(*kino_CFReader_close_f_t)(kino_CompoundFileReader *self);

#define Kino_CFReader_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_CFReader_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_CFReader_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_CFReader_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_CFReader_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_CFReader_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_CFReader_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_CFReader_Open_OutStream(_self, _arg1) \
    (_self)->_->open_outstream((kino_Folder*)_self, _arg1)

#define Kino_CFReader_Open_InStream(_self, _arg1) \
    (_self)->_->open_instream((kino_Folder*)_self, _arg1)

#define Kino_CFReader_List(_self) \
    (_self)->_->list((kino_Folder*)_self)

#define Kino_CFReader_File_Exists(_self, _arg1) \
    (_self)->_->file_exists((kino_Folder*)_self, _arg1)

#define Kino_CFReader_Rename_File(_self, _arg1, _arg2) \
    (_self)->_->rename_file((kino_Folder*)_self, _arg1, _arg2)

#define Kino_CFReader_Delete_File(_self, _arg1) \
    (_self)->_->delete_file((kino_Folder*)_self, _arg1)

#define Kino_CFReader_Slurp_File(_self, _arg1) \
    (_self)->_->slurp_file((kino_Folder*)_self, _arg1)

#define Kino_CFReader_Latest_Gen(_self, _arg1, _arg2) \
    (_self)->_->latest_gen((kino_Folder*)_self, _arg1, _arg2)

#define Kino_CFReader_Make_Lock(_self, _arg1, _arg2, _arg3) \
    (_self)->_->make_lock((kino_Folder*)_self, _arg1, _arg2, _arg3)

#define Kino_CFReader_Run_Locked(_self, _arg1, _arg2, _arg3, _arg4, _arg5) \
    (_self)->_->run_locked((kino_Folder*)_self, _arg1, _arg2, _arg3, _arg4, _arg5)

#define Kino_CFReader_Close_F(_self) \
    (_self)->_->close_f((kino_Folder*)_self)

struct KINO_COMPOUNDFILEREADER_VTABLE {
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

extern KINO_COMPOUNDFILEREADER_VTABLE KINO_COMPOUNDFILEREADER;

#ifdef KINO_USE_SHORT_NAMES
  #define CompoundFileReader kino_CompoundFileReader
  #define COMPOUNDFILEREADER KINO_COMPOUNDFILEREADER
  #define CFReader_new kino_CFReader_new
  #define CFReader_destroy kino_CFReader_destroy
  #define CFReader_open_instream kino_CFReader_open_instream
  #define CFReader_list kino_CFReader_list
  #define CFReader_file_exists kino_CFReader_file_exists
  #define CFReader_slurp_file kino_CFReader_slurp_file
  #define CFReader_close_f kino_CFReader_close_f
  #define CFReader_Clone Kino_CFReader_Clone
  #define CFReader_Destroy Kino_CFReader_Destroy
  #define CFReader_Equals Kino_CFReader_Equals
  #define CFReader_Hash_Code Kino_CFReader_Hash_Code
  #define CFReader_Is_A Kino_CFReader_Is_A
  #define CFReader_To_String Kino_CFReader_To_String
  #define CFReader_Serialize Kino_CFReader_Serialize
  #define CFReader_Open_OutStream Kino_CFReader_Open_OutStream
  #define CFReader_Open_InStream Kino_CFReader_Open_InStream
  #define CFReader_List Kino_CFReader_List
  #define CFReader_File_Exists Kino_CFReader_File_Exists
  #define CFReader_Rename_File Kino_CFReader_Rename_File
  #define CFReader_Delete_File Kino_CFReader_Delete_File
  #define CFReader_Slurp_File Kino_CFReader_Slurp_File
  #define CFReader_Latest_Gen Kino_CFReader_Latest_Gen
  #define CFReader_Make_Lock Kino_CFReader_Make_Lock
  #define CFReader_Run_Locked Kino_CFReader_Run_Locked
  #define CFReader_Close_F Kino_CFReader_Close_F
  #define COMPOUNDFILEREADER KINO_COMPOUNDFILEREADER
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_COMPOUNDFILEREADER_MEMBER_VARS \
    struct kino_ByteBuf * path; \
    struct kino_InvIndex * invindex; \
    struct kino_Folder * folder; \
    struct kino_SegInfo * seg_info; \
    struct kino_Hash * entries; \
    struct kino_InStream * instream;


#ifdef KINO_WANT_COMPOUNDFILEREADER_VTABLE
KINO_COMPOUNDFILEREADER_VTABLE KINO_COMPOUNDFILEREADER = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_FOLDER,
    "KinoSearch::Index::CompoundFileReader",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_CFReader_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_Folder_open_outstream_t)kino_Folder_open_outstream,
    (kino_Folder_open_instream_t)kino_CFReader_open_instream,
    (kino_Folder_list_t)kino_CFReader_list,
    (kino_Folder_file_exists_t)kino_CFReader_file_exists,
    (kino_Folder_rename_file_t)kino_Folder_rename_file,
    (kino_Folder_delete_file_t)kino_Folder_delete_file,
    (kino_Folder_slurp_file_t)kino_CFReader_slurp_file,
    (kino_Folder_latest_gen_t)kino_Folder_latest_gen,
    (kino_Folder_make_lock_t)kino_Folder_make_lock,
    (kino_Folder_run_locked_t)kino_Folder_run_locked,
    (kino_Folder_close_f_t)kino_CFReader_close_f
};
#endif /* KINO_WANT_COMPOUNDFILEREADER_VTABLE */

#endif /* R_KINO_CFREADER */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
