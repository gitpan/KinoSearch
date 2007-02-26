/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_POSTING
#define R_KINO_POSTING 1

#include "KinoSearch/Index/Posting.h"

typedef struct kino_ByteBuf*
(*kino_Posting_serialize_t)(kino_Posting *self);

#define Kino_Posting_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_Posting_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_Posting_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_Posting_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_Posting_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_Posting_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_Posting_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

struct KINO_POSTING_VTABLE {
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

extern KINO_POSTING_VTABLE KINO_POSTING;

#ifdef KINO_USE_SHORT_NAMES
  #define Posting kino_Posting
  #define POSTING KINO_POSTING
  #define Posting_deserialize kino_Posting_deserialize
  #define Posting_serialize kino_Posting_serialize
  #define Posting_Clone Kino_Posting_Clone
  #define Posting_Destroy Kino_Posting_Destroy
  #define Posting_Equals Kino_Posting_Equals
  #define Posting_Hash_Code Kino_Posting_Hash_Code
  #define Posting_Is_A Kino_Posting_Is_A
  #define Posting_To_String Kino_Posting_To_String
  #define Posting_Serialize Kino_Posting_Serialize
  #define POSTING KINO_POSTING
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_POSTING_MEMBER_VARS \
    struct kino_ByteBuf * stringified; \
    kino_i32_t * positions;


#ifdef KINO_WANT_POSTING_VTABLE
KINO_POSTING_VTABLE KINO_POSTING = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Index::Posting",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Obj_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Posting_serialize
};
#endif /* KINO_WANT_POSTING_VTABLE */

#endif /* R_KINO_POSTING */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
