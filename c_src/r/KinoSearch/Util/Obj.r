/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_OBJ
#define R_KINO_OBJ 1

#include "KinoSearch/Util/Obj.h"

#define KINO_OBJ_BOILERPLATE

typedef kino_Obj*
(*kino_Obj_clone_t)(kino_Obj *self);

typedef void
(*kino_Obj_destroy_t)(kino_Obj *self);

typedef chy_bool_t
(*kino_Obj_equals_t)(kino_Obj *self, kino_Obj *other);

typedef chy_i32_t
(*kino_Obj_hash_code_t)(kino_Obj *self);

typedef chy_bool_t
(*kino_Obj_is_a_t)(kino_Obj *self, KINO_OBJ_VTABLE *target_vtable);

typedef struct kino_ByteBuf*
(*kino_Obj_to_string_t)(kino_Obj *self);

typedef void
(*kino_Obj_serialize_t)(kino_Obj *self, struct kino_ByteBuf *target);

#define Kino_Obj_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_Obj_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_Obj_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_Obj_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_Obj_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_Obj_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_Obj_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

struct KINO_OBJ_VTABLE {
    KINO_OBJ_VTABLE *_;
    chy_u32_t refcount;
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

extern KINO_OBJ_VTABLE KINO_OBJ;

#ifdef KINO_USE_SHORT_NAMES
  #define Obj kino_Obj
  #define OBJ KINO_OBJ
  #define Obj_new kino_Obj_new
  #define Obj_dec_refcount kino_Obj_dec_refcount
  #define Obj_clone_t kino_Obj_clone_t
  #define Obj_clone kino_Obj_clone
  #define Obj_destroy_t kino_Obj_destroy_t
  #define Obj_destroy kino_Obj_destroy
  #define Obj_equals_t kino_Obj_equals_t
  #define Obj_equals kino_Obj_equals
  #define Obj_hash_code_t kino_Obj_hash_code_t
  #define Obj_hash_code kino_Obj_hash_code
  #define Obj_is_a_t kino_Obj_is_a_t
  #define Obj_is_a kino_Obj_is_a
  #define Obj_to_string_t kino_Obj_to_string_t
  #define Obj_to_string kino_Obj_to_string
  #define Obj_serialize_t kino_Obj_serialize_t
  #define Obj_serialize kino_Obj_serialize
  #define Obj_Clone Kino_Obj_Clone
  #define Obj_Destroy Kino_Obj_Destroy
  #define Obj_Equals Kino_Obj_Equals
  #define Obj_Hash_Code Kino_Obj_Hash_Code
  #define Obj_Is_A Kino_Obj_Is_A
  #define Obj_To_String Kino_Obj_To_String
  #define Obj_Serialize Kino_Obj_Serialize
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_OBJ_MEMBER_VARS \
    chy_u32_t  refcount

#ifdef KINO_WANT_OBJ_VTABLE
KINO_OBJ_VTABLE KINO_OBJ = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    NULL,
    "KinoSearch::Util::Obj",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Obj_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize
};
#endif /* KINO_WANT_OBJ_VTABLE */

#undef KINO_OBJ_BOILERPLATE


#endif /* R_KINO_OBJ */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

