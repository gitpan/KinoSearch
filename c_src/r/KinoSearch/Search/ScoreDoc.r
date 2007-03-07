/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_SCOREDOC
#define R_KINO_SCOREDOC 1

#include "KinoSearch/Search/ScoreDoc.h"

typedef void
(*kino_ScoreDoc_serialize_t)(kino_ScoreDoc *self, struct kino_ByteBuf *target);

#define Kino_ScoreDoc_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_ScoreDoc_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_ScoreDoc_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_ScoreDoc_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_ScoreDoc_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_ScoreDoc_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_ScoreDoc_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

struct KINO_SCOREDOC_VTABLE {
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

extern KINO_SCOREDOC_VTABLE KINO_SCOREDOC;

#ifdef KINO_USE_SHORT_NAMES
  #define ScoreDoc kino_ScoreDoc
  #define SCOREDOC KINO_SCOREDOC
  #define ScoreDoc_new kino_ScoreDoc_new
  #define ScoreDoc_deserialize kino_ScoreDoc_deserialize
  #define ScoreDoc_serialize kino_ScoreDoc_serialize
  #define ScoreDoc_Clone Kino_ScoreDoc_Clone
  #define ScoreDoc_Destroy Kino_ScoreDoc_Destroy
  #define ScoreDoc_Equals Kino_ScoreDoc_Equals
  #define ScoreDoc_Hash_Code Kino_ScoreDoc_Hash_Code
  #define ScoreDoc_Is_A Kino_ScoreDoc_Is_A
  #define ScoreDoc_To_String Kino_ScoreDoc_To_String
  #define ScoreDoc_Serialize Kino_ScoreDoc_Serialize
  #define SCOREDOC KINO_SCOREDOC
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_SCOREDOC_MEMBER_VARS \
    kino_u32_t  refcount; \
    kino_u32_t  id; \
    float  score


#ifdef KINO_WANT_SCOREDOC_VTABLE
KINO_SCOREDOC_VTABLE KINO_SCOREDOC = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Search::ScoreDoc",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Obj_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_ScoreDoc_serialize
};
#endif /* KINO_WANT_SCOREDOC_VTABLE */

#endif /* R_KINO_SCOREDOC */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */