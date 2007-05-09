/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_TALLY
#define R_KINO_TALLY 1

#include "KinoSearch/Search/Tally.h"

#define KINO_TALLY_BOILERPLATE



#define Kino_Tally_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_Tally_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_Tally_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_Tally_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_Tally_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_Tally_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_Tally_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

struct KINO_TALLY_VTABLE {
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

extern KINO_TALLY_VTABLE KINO_TALLY;

#ifdef KINO_USE_SHORT_NAMES
  #define Tally kino_Tally
  #define TALLY KINO_TALLY
  #define Tally_new kino_Tally_new
  #define Tally_Clone Kino_Tally_Clone
  #define Tally_Destroy Kino_Tally_Destroy
  #define Tally_Equals Kino_Tally_Equals
  #define Tally_Hash_Code Kino_Tally_Hash_Code
  #define Tally_Is_A Kino_Tally_Is_A
  #define Tally_To_String Kino_Tally_To_String
  #define Tally_Serialize Kino_Tally_Serialize
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_TALLY_MEMBER_VARS \
    chy_u32_t  refcount; \
    float  score; \
    chy_u32_t  num_matchers; \
    chy_u32_t  num_prox; \
    chy_u32_t * prox

#ifdef KINO_WANT_TALLY_VTABLE
KINO_TALLY_VTABLE KINO_TALLY = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Search::Tally",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Obj_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize
};
#endif /* KINO_WANT_TALLY_VTABLE */

#undef KINO_TALLY_BOILERPLATE


#endif /* R_KINO_TALLY */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
