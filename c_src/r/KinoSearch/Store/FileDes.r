/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_FILEDES
#define R_KINO_FILEDES 1

#include "KinoSearch/Store/FileDes.h"

typedef void
(*kino_FileDes_fdseek_t)(kino_FileDes *self, kino_u64_t target);

typedef void
(*kino_FileDes_fdread_t)(kino_FileDes *self, char *dest, kino_u32_t dest_offset, 
                    kino_u32_t len);

typedef void
(*kino_FileDes_fdwrite_t)(kino_FileDes *self, char* buf, kino_u32_t len);

typedef kino_u64_t
(*kino_FileDes_fdlength_t)(kino_FileDes *self);

typedef void
(*kino_FileDes_fdclose_t)(kino_FileDes *self);

#define Kino_FileDes_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_FileDes_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_FileDes_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_FileDes_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_FileDes_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_FileDes_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_FileDes_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_FileDes_FDSeek(_self, _arg1) \
    (_self)->_->fdseek((kino_FileDes*)_self, _arg1)

#define Kino_FileDes_FDRead(_self, _arg1, _arg2, _arg3) \
    (_self)->_->fdread((kino_FileDes*)_self, _arg1, _arg2, _arg3)

#define Kino_FileDes_FDWrite(_self, _arg1, _arg2) \
    (_self)->_->fdwrite((kino_FileDes*)_self, _arg1, _arg2)

#define Kino_FileDes_FDLength(_self) \
    (_self)->_->fdlength((kino_FileDes*)_self)

#define Kino_FileDes_FDClose(_self) \
    (_self)->_->fdclose((kino_FileDes*)_self)

struct KINO_FILEDES_VTABLE {
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
    kino_FileDes_fdseek_t fdseek;
    kino_FileDes_fdread_t fdread;
    kino_FileDes_fdwrite_t fdwrite;
    kino_FileDes_fdlength_t fdlength;
    kino_FileDes_fdclose_t fdclose;
};

extern KINO_FILEDES_VTABLE KINO_FILEDES;

#ifdef KINO_USE_SHORT_NAMES
  #define FileDes kino_FileDes
  #define FILEDES KINO_FILEDES
  #define FileDes_fdseek_t kino_FileDes_fdseek_t
  #define FileDes_fdseek kino_FileDes_fdseek
  #define FileDes_fdread_t kino_FileDes_fdread_t
  #define FileDes_fdread kino_FileDes_fdread
  #define FileDes_fdwrite_t kino_FileDes_fdwrite_t
  #define FileDes_fdwrite kino_FileDes_fdwrite
  #define FileDes_fdlength_t kino_FileDes_fdlength_t
  #define FileDes_fdlength kino_FileDes_fdlength
  #define FileDes_fdclose_t kino_FileDes_fdclose_t
  #define FileDes_fdclose kino_FileDes_fdclose
  #define FileDes_Clone Kino_FileDes_Clone
  #define FileDes_Destroy Kino_FileDes_Destroy
  #define FileDes_Equals Kino_FileDes_Equals
  #define FileDes_Hash_Code Kino_FileDes_Hash_Code
  #define FileDes_Is_A Kino_FileDes_Is_A
  #define FileDes_To_String Kino_FileDes_To_String
  #define FileDes_Serialize Kino_FileDes_Serialize
  #define FileDes_FDSeek Kino_FileDes_FDSeek
  #define FileDes_FDRead Kino_FileDes_FDRead
  #define FileDes_FDWrite Kino_FileDes_FDWrite
  #define FileDes_FDLength Kino_FileDes_FDLength
  #define FileDes_FDClose Kino_FileDes_FDClose
  #define FILEDES KINO_FILEDES
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_FILEDES_MEMBER_VARS \
    kino_u32_t  refcount; \
    char * path; \
    char * mode; \
    kino_u64_t  pos; \
    kino_i32_t  stream_count


#ifdef KINO_WANT_FILEDES_VTABLE
KINO_FILEDES_VTABLE KINO_FILEDES = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Store::FileDes",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Obj_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_FileDes_fdseek_t)kino_FileDes_fdseek,
    (kino_FileDes_fdread_t)kino_FileDes_fdread,
    (kino_FileDes_fdwrite_t)kino_FileDes_fdwrite,
    (kino_FileDes_fdlength_t)kino_FileDes_fdlength,
    (kino_FileDes_fdclose_t)kino_FileDes_fdclose
};
#endif /* KINO_WANT_FILEDES_VTABLE */

#endif /* R_KINO_FILEDES */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
