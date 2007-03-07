/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_FIELDDOC
#define R_KINO_FIELDDOC 1

#include "KinoSearch/Search/FieldDoc.h"

typedef void
(*kino_FieldDoc_destroy_t)(kino_FieldDoc *self);

#define Kino_FieldDoc_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_FieldDoc_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_FieldDoc_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_FieldDoc_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_FieldDoc_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_FieldDoc_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_FieldDoc_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

struct KINO_FIELDDOC_VTABLE {
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

extern KINO_FIELDDOC_VTABLE KINO_FIELDDOC;

#ifdef KINO_USE_SHORT_NAMES
  #define FieldDoc kino_FieldDoc
  #define FIELDDOC KINO_FIELDDOC
  #define FieldDoc_new kino_FieldDoc_new
  #define FieldDoc_destroy kino_FieldDoc_destroy
  #define FieldDoc_Clone Kino_FieldDoc_Clone
  #define FieldDoc_Destroy Kino_FieldDoc_Destroy
  #define FieldDoc_Equals Kino_FieldDoc_Equals
  #define FieldDoc_Hash_Code Kino_FieldDoc_Hash_Code
  #define FieldDoc_Is_A Kino_FieldDoc_Is_A
  #define FieldDoc_To_String Kino_FieldDoc_To_String
  #define FieldDoc_Serialize Kino_FieldDoc_Serialize
  #define FIELDDOC KINO_FIELDDOC
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_FIELDDOC_MEMBER_VARS \
    kino_u32_t  refcount; \
    kino_u32_t  id; \
    float  score; \
    struct kino_FieldDocCollator * collator


#ifdef KINO_WANT_FIELDDOC_VTABLE
KINO_FIELDDOC_VTABLE KINO_FIELDDOC = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_SCOREDOC,
    "KinoSearch::Search::FieldDoc",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_FieldDoc_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_ScoreDoc_serialize
};
#endif /* KINO_WANT_FIELDDOC_VTABLE */

#endif /* R_KINO_FIELDDOC */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
