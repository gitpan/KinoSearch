/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_TOKEN
#define R_KINO_TOKEN 1

#include "KinoSearch/Analysis/Token.h"

typedef void
(*kino_Token_destroy_t)(kino_Token *token);

#define Kino_Token_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_Token_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_Token_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_Token_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_Token_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_Token_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_Token_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

struct KINO_TOKEN_VTABLE {
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
};

extern KINO_TOKEN_VTABLE KINO_TOKEN;

#ifdef KINO_USE_SHORT_NAMES
  #define Token kino_Token
  #define TOKEN KINO_TOKEN
  #define Token_new kino_Token_new
  #define Token_compare kino_Token_compare
  #define Token_destroy kino_Token_destroy
  #define Token_Clone Kino_Token_Clone
  #define Token_Destroy Kino_Token_Destroy
  #define Token_Equals Kino_Token_Equals
  #define Token_Hash_Code Kino_Token_Hash_Code
  #define Token_Is_A Kino_Token_Is_A
  #define Token_To_String Kino_Token_To_String
  #define Token_Serialize Kino_Token_Serialize
  #define TOKEN KINO_TOKEN
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_TOKEN_MEMBER_VARS \
    char * text; \
    size_t  len; \
    kino_u32_t  start_offset; \
    kino_u32_t  end_offset; \
    float  boost; \
    kino_i32_t  pos_inc; \
    kino_i32_t  pos;


#ifdef KINO_WANT_TOKEN_VTABLE
KINO_TOKEN_VTABLE KINO_TOKEN = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Analysis::Token",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Token_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize
};
#endif /* KINO_WANT_TOKEN_VTABLE */

#endif /* R_KINO_TOKEN */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
