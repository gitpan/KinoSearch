/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_INSTREAM
#define R_KINO_INSTREAM 1

#include "KinoSearch/Store/InStream.h"

typedef kino_InStream*
(*kino_InStream_clone_t)(kino_InStream *self);

typedef void
(*kino_InStream_destroy_t)(kino_InStream *self);

typedef void
(*kino_InStream_sseek_t)(kino_InStream *self, kino_u64_t target);

typedef kino_u64_t
(*kino_InStream_stell_t)(kino_InStream *self);

typedef char
(*kino_InStream_read_byte_t)(kino_InStream *self);

typedef void
(*kino_InStream_read_bytes_t)(kino_InStream *self, char *buf, size_t len);

typedef void
(*kino_InStream_read_chars_t)(kino_InStream *self, char *buf, size_t start, 
                         size_t len);

typedef kino_u32_t
(*kino_InStream_read_int_t)(kino_InStream *self);

typedef kino_u64_t
(*kino_InStream_read_long_t)(kino_InStream *self);

typedef kino_u32_t
(*kino_InStream_read_vint_t)(kino_InStream *self);

typedef kino_u64_t
(*kino_InStream_read_vlong_t)(kino_InStream *self);

typedef kino_u64_t
(*kino_InStream_slength_t)(kino_InStream *self);

typedef kino_InStream*
(*kino_InStream_reopen_t)(kino_InStream *self, kino_u64_t offset, kino_u64_t len);

typedef void
(*kino_InStream_sclose_t)(kino_InStream *self);

#define Kino_InStream_Clone(_self) \
    kino_InStream_clone((kino_InStream*)_self)

#define Kino_InStream_Destroy(_self) \
    kino_InStream_destroy((kino_InStream*)_self)

#define Kino_InStream_Equals(_self, _arg1) \
    kino_Obj_equals((kino_Obj*)_self, _arg1)

#define Kino_InStream_Hash_Code(_self) \
    kino_Obj_hash_code((kino_Obj*)_self)

#define Kino_InStream_Is_A(_self, _arg1) \
    kino_Obj_is_a((kino_Obj*)_self, _arg1)

#define Kino_InStream_To_String(_self) \
    kino_Obj_to_string((kino_Obj*)_self)

#define Kino_InStream_Serialize(_self, _arg1) \
    kino_Obj_serialize((kino_Obj*)_self, _arg1)

#define Kino_InStream_SSeek(_self, _arg1) \
    kino_InStream_sseek((kino_InStream*)_self, _arg1)

#define Kino_InStream_STell(_self) \
    kino_InStream_stell((kino_InStream*)_self)

#define Kino_InStream_Read_Byte(_self) \
    kino_InStream_read_byte((kino_InStream*)_self)

#define Kino_InStream_Read_Bytes(_self, _arg1, _arg2) \
    kino_InStream_read_bytes((kino_InStream*)_self, _arg1, _arg2)

#define Kino_InStream_Read_Chars(_self, _arg1, _arg2, _arg3) \
    kino_InStream_read_chars((kino_InStream*)_self, _arg1, _arg2, _arg3)

#define Kino_InStream_Read_Int(_self) \
    kino_InStream_read_int((kino_InStream*)_self)

#define Kino_InStream_Read_Long(_self) \
    kino_InStream_read_long((kino_InStream*)_self)

#define Kino_InStream_Read_VInt(_self) \
    kino_InStream_read_vint((kino_InStream*)_self)

#define Kino_InStream_Read_VLong(_self) \
    kino_InStream_read_vlong((kino_InStream*)_self)

#define Kino_InStream_SLength(_self) \
    kino_InStream_slength((kino_InStream*)_self)

#define Kino_InStream_Reopen(_self, _arg1, _arg2) \
    kino_InStream_reopen((kino_InStream*)_self, _arg1, _arg2)

#define Kino_InStream_SClose(_self) \
    kino_InStream_sclose((kino_InStream*)_self)

struct KINO_INSTREAM_VTABLE {
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
    kino_InStream_sseek_t sseek;
    kino_InStream_stell_t stell;
    kino_InStream_read_byte_t read_byte;
    kino_InStream_read_bytes_t read_bytes;
    kino_InStream_read_chars_t read_chars;
    kino_InStream_read_int_t read_int;
    kino_InStream_read_long_t read_long;
    kino_InStream_read_vint_t read_vint;
    kino_InStream_read_vlong_t read_vlong;
    kino_InStream_slength_t slength;
    kino_InStream_reopen_t reopen;
    kino_InStream_sclose_t sclose;
};

extern KINO_INSTREAM_VTABLE KINO_INSTREAM;

#ifdef KINO_USE_SHORT_NAMES
  #define InStream kino_InStream
  #define INSTREAM KINO_INSTREAM
  #define InStream_new kino_InStream_new
  #define InStream_decode_vint kino_InStream_decode_vint
  #define InStream_clone_t kino_InStream_clone_t
  #define InStream_clone kino_InStream_clone
  #define InStream_destroy_t kino_InStream_destroy_t
  #define InStream_destroy kino_InStream_destroy
  #define InStream_sseek_t kino_InStream_sseek_t
  #define InStream_sseek kino_InStream_sseek
  #define InStream_stell_t kino_InStream_stell_t
  #define InStream_stell kino_InStream_stell
  #define InStream_read_byte_t kino_InStream_read_byte_t
  #define InStream_read_byte kino_InStream_read_byte
  #define InStream_read_bytes_t kino_InStream_read_bytes_t
  #define InStream_read_bytes kino_InStream_read_bytes
  #define InStream_read_chars_t kino_InStream_read_chars_t
  #define InStream_read_chars kino_InStream_read_chars
  #define InStream_read_int_t kino_InStream_read_int_t
  #define InStream_read_int kino_InStream_read_int
  #define InStream_read_long_t kino_InStream_read_long_t
  #define InStream_read_long kino_InStream_read_long
  #define InStream_read_vint_t kino_InStream_read_vint_t
  #define InStream_read_vint kino_InStream_read_vint
  #define InStream_read_vlong_t kino_InStream_read_vlong_t
  #define InStream_read_vlong kino_InStream_read_vlong
  #define InStream_slength_t kino_InStream_slength_t
  #define InStream_slength kino_InStream_slength
  #define InStream_reopen_t kino_InStream_reopen_t
  #define InStream_reopen kino_InStream_reopen
  #define InStream_sclose_t kino_InStream_sclose_t
  #define InStream_sclose kino_InStream_sclose
  #define InStream_Clone Kino_InStream_Clone
  #define InStream_Destroy Kino_InStream_Destroy
  #define InStream_Equals Kino_InStream_Equals
  #define InStream_Hash_Code Kino_InStream_Hash_Code
  #define InStream_Is_A Kino_InStream_Is_A
  #define InStream_To_String Kino_InStream_To_String
  #define InStream_Serialize Kino_InStream_Serialize
  #define InStream_SSeek Kino_InStream_SSeek
  #define InStream_STell Kino_InStream_STell
  #define InStream_Read_Byte Kino_InStream_Read_Byte
  #define InStream_Read_Bytes Kino_InStream_Read_Bytes
  #define InStream_Read_Chars Kino_InStream_Read_Chars
  #define InStream_Read_Int Kino_InStream_Read_Int
  #define InStream_Read_Long Kino_InStream_Read_Long
  #define InStream_Read_VInt Kino_InStream_Read_VInt
  #define InStream_Read_VLong Kino_InStream_Read_VLong
  #define InStream_SLength Kino_InStream_SLength
  #define InStream_Reopen Kino_InStream_Reopen
  #define InStream_SClose Kino_InStream_SClose
  #define INSTREAM KINO_INSTREAM
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_INSTREAM_MEMBER_VARS \
    kino_u32_t  refcount; \
    kino_u64_t  offset; \
    kino_u64_t  len; \
    char * buf; \
    kino_u64_t  buf_start; \
    kino_u32_t  buf_len; \
    kino_u32_t  buf_pos; \
    struct kino_FileDes * file_des


#ifdef KINO_WANT_INSTREAM_VTABLE
KINO_INSTREAM_VTABLE KINO_INSTREAM = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Store::InStream",
    (kino_Obj_clone_t)kino_InStream_clone,
    (kino_Obj_destroy_t)kino_InStream_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_InStream_sseek_t)kino_InStream_sseek,
    (kino_InStream_stell_t)kino_InStream_stell,
    (kino_InStream_read_byte_t)kino_InStream_read_byte,
    (kino_InStream_read_bytes_t)kino_InStream_read_bytes,
    (kino_InStream_read_chars_t)kino_InStream_read_chars,
    (kino_InStream_read_int_t)kino_InStream_read_int,
    (kino_InStream_read_long_t)kino_InStream_read_long,
    (kino_InStream_read_vint_t)kino_InStream_read_vint,
    (kino_InStream_read_vlong_t)kino_InStream_read_vlong,
    (kino_InStream_slength_t)kino_InStream_slength,
    (kino_InStream_reopen_t)kino_InStream_reopen,
    (kino_InStream_sclose_t)kino_InStream_sclose
};
#endif /* KINO_WANT_INSTREAM_VTABLE */

#endif /* R_KINO_INSTREAM */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */