/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_TERM
#define R_KINO_TERM 1

#include "KinoSearch/Index/Term.h"

typedef kino_Term*
(*kino_Term_clone_t)(kino_Term *self);

typedef void
(*kino_Term_destroy_t)(kino_Term *self);

typedef kino_bool_t
(*kino_Term_equals_t)(kino_Term *self, kino_Term *other);

typedef struct kino_ByteBuf*
(*kino_Term_to_string_t)(kino_Term *self);

typedef void
(*kino_Term_serialize_t)(kino_Term *self, struct kino_ByteBuf *target);

typedef struct kino_ByteBuf*
(*kino_Term_get_field_t)(kino_Term *self);

typedef struct kino_ByteBuf*
(*kino_Term_get_text_t)(kino_Term *self);

typedef void
(*kino_Term_copy_t)(kino_Term *self, kino_Term *other);

#define Kino_Term_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_Term_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_Term_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_Term_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_Term_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_Term_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_Term_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_Term_Get_Field(_self) \
    (_self)->_->get_field((kino_Term*)_self)

#define Kino_Term_Get_Text(_self) \
    (_self)->_->get_text((kino_Term*)_self)

#define Kino_Term_Copy(_self, _arg1) \
    (_self)->_->copy((kino_Term*)_self, _arg1)

struct KINO_TERM_VTABLE {
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
    kino_Term_get_field_t get_field;
    kino_Term_get_text_t get_text;
    kino_Term_copy_t copy;
};

extern KINO_TERM_VTABLE KINO_TERM;

#ifdef KINO_USE_SHORT_NAMES
  #define Term kino_Term
  #define TERM KINO_TERM
  #define Term_new kino_Term_new
  #define Term_new_str kino_Term_new_str
  #define Term_deserialize kino_Term_deserialize
  #define Term_clone kino_Term_clone
  #define Term_destroy kino_Term_destroy
  #define Term_equals kino_Term_equals
  #define Term_to_string kino_Term_to_string
  #define Term_serialize kino_Term_serialize
  #define Term_get_field_t kino_Term_get_field_t
  #define Term_get_field kino_Term_get_field
  #define Term_get_text_t kino_Term_get_text_t
  #define Term_get_text kino_Term_get_text
  #define Term_copy_t kino_Term_copy_t
  #define Term_copy kino_Term_copy
  #define Term_Clone Kino_Term_Clone
  #define Term_Destroy Kino_Term_Destroy
  #define Term_Equals Kino_Term_Equals
  #define Term_Hash_Code Kino_Term_Hash_Code
  #define Term_Is_A Kino_Term_Is_A
  #define Term_To_String Kino_Term_To_String
  #define Term_Serialize Kino_Term_Serialize
  #define Term_Get_Field Kino_Term_Get_Field
  #define Term_Get_Text Kino_Term_Get_Text
  #define Term_Copy Kino_Term_Copy
  #define TERM KINO_TERM
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_TERM_MEMBER_VARS \
    kino_u32_t  refcount; \
    struct kino_ByteBuf * field; \
    struct kino_ByteBuf * text


#ifdef KINO_WANT_TERM_VTABLE
KINO_TERM_VTABLE KINO_TERM = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Index::Term",
    (kino_Obj_clone_t)kino_Term_clone,
    (kino_Obj_destroy_t)kino_Term_destroy,
    (kino_Obj_equals_t)kino_Term_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Term_to_string,
    (kino_Obj_serialize_t)kino_Term_serialize,
    (kino_Term_get_field_t)kino_Term_get_field,
    (kino_Term_get_text_t)kino_Term_get_text,
    (kino_Term_copy_t)kino_Term_copy
};
#endif /* KINO_WANT_TERM_VTABLE */

#endif /* R_KINO_TERM */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */