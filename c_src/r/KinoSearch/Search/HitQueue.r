/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_HITQ
#define R_KINO_HITQ 1

#include "KinoSearch/Search/HitQueue.h"

#define Kino_HitQ_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_HitQ_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_HitQ_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_HitQ_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_HitQ_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_HitQ_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_HitQ_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_HitQ_Insert(_self, _arg1) \
    (_self)->_->insert((kino_PriorityQueue*)_self, _arg1)

#define Kino_HitQ_Pop(_self) \
    (_self)->_->pop((kino_PriorityQueue*)_self)

#define Kino_HitQ_Peek(_self) \
    (_self)->_->peek((kino_PriorityQueue*)_self)

struct KINO_HITQUEUE_VTABLE {
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
    kino_PriQ_insert_t insert;
    kino_PriQ_pop_t pop;
    kino_PriQ_peek_t peek;
};

extern KINO_HITQUEUE_VTABLE KINO_HITQUEUE;

#ifdef KINO_USE_SHORT_NAMES
  #define HitQueue kino_HitQueue
  #define HITQUEUE KINO_HITQUEUE
  #define HitQ_new kino_HitQ_new
  #define HitQ_Clone Kino_HitQ_Clone
  #define HitQ_Destroy Kino_HitQ_Destroy
  #define HitQ_Equals Kino_HitQ_Equals
  #define HitQ_Hash_Code Kino_HitQ_Hash_Code
  #define HitQ_Is_A Kino_HitQ_Is_A
  #define HitQ_To_String Kino_HitQ_To_String
  #define HitQ_Serialize Kino_HitQ_Serialize
  #define HitQ_Insert Kino_HitQ_Insert
  #define HitQ_Pop Kino_HitQ_Pop
  #define HitQ_Peek Kino_HitQ_Peek
  #define HITQUEUE KINO_HITQUEUE
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_HITQUEUE_MEMBER_VARS \
    kino_u32_t  refcount; \
    kino_u32_t  size; \
    kino_u32_t  max_size; \
    void ** heap; \
    kino_PriQ_less_than_t  less_than; \
    kino_PriQ_free_elem_t  free_elem


#ifdef KINO_WANT_HITQUEUE_VTABLE
KINO_HITQUEUE_VTABLE KINO_HITQUEUE = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_PRIORITYQUEUE,
    "KinoSearch::Search::HitQueue",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_PriQ_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_PriQ_insert_t)kino_PriQ_insert,
    (kino_PriQ_pop_t)kino_PriQ_pop,
    (kino_PriQ_peek_t)kino_PriQ_peek
};
#endif /* KINO_WANT_HITQUEUE_VTABLE */

#endif /* R_KINO_HITQ */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */