/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_TERMLIST
#define R_KINO_TERMLIST 1

#include "KinoSearch/Index/TermList.h"

typedef void
(*kino_TermList_seek_t)(kino_TermList *self, struct kino_Term *term);

typedef kino_bool_t
(*kino_TermList_next_t)(kino_TermList *self);

typedef void
(*kino_TermList_reset_t)(kino_TermList* self);

typedef kino_i32_t
(*kino_TermList_get_term_num_t)(kino_TermList *self);

typedef struct kino_Term*
(*kino_TermList_get_term_t)(kino_TermList *self);

typedef struct kino_IntMap*
(*kino_TermList_build_sort_cache_t)(kino_TermList *self, 
                               struct kino_TermDocs *term_docs, 
                               kino_u32_t max_doc);

#define Kino_TermList_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_TermList_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_TermList_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_TermList_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_TermList_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_TermList_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_TermList_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_TermList_Seek(_self, _arg1) \
    (_self)->_->seek((kino_TermList*)_self, _arg1)

#define Kino_TermList_Next(_self) \
    (_self)->_->next((kino_TermList*)_self)

#define Kino_TermList_Reset(_self) \
    (_self)->_->reset((kino_TermList*)_self)

#define Kino_TermList_Get_Term_Num(_self) \
    (_self)->_->get_term_num((kino_TermList*)_self)

#define Kino_TermList_Get_Term(_self) \
    (_self)->_->get_term((kino_TermList*)_self)

#define Kino_TermList_Build_Sort_Cache(_self, _arg1, _arg2) \
    (_self)->_->build_sort_cache((kino_TermList*)_self, _arg1, _arg2)

struct KINO_TERMLIST_VTABLE {
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
    kino_TermList_seek_t seek;
    kino_TermList_next_t next;
    kino_TermList_reset_t reset;
    kino_TermList_get_term_num_t get_term_num;
    kino_TermList_get_term_t get_term;
    kino_TermList_build_sort_cache_t build_sort_cache;
};

extern KINO_TERMLIST_VTABLE KINO_TERMLIST;

#ifdef KINO_USE_SHORT_NAMES
  #define TermList kino_TermList
  #define TERMLIST KINO_TERMLIST
  #define TermList_seek_t kino_TermList_seek_t
  #define TermList_seek kino_TermList_seek
  #define TermList_next_t kino_TermList_next_t
  #define TermList_next kino_TermList_next
  #define TermList_reset_t kino_TermList_reset_t
  #define TermList_reset kino_TermList_reset
  #define TermList_get_term_num_t kino_TermList_get_term_num_t
  #define TermList_get_term_num kino_TermList_get_term_num
  #define TermList_get_term_t kino_TermList_get_term_t
  #define TermList_get_term kino_TermList_get_term
  #define TermList_build_sort_cache_t kino_TermList_build_sort_cache_t
  #define TermList_build_sort_cache kino_TermList_build_sort_cache
  #define TermList_Clone Kino_TermList_Clone
  #define TermList_Destroy Kino_TermList_Destroy
  #define TermList_Equals Kino_TermList_Equals
  #define TermList_Hash_Code Kino_TermList_Hash_Code
  #define TermList_Is_A Kino_TermList_Is_A
  #define TermList_To_String Kino_TermList_To_String
  #define TermList_Serialize Kino_TermList_Serialize
  #define TermList_Seek Kino_TermList_Seek
  #define TermList_Next Kino_TermList_Next
  #define TermList_Reset Kino_TermList_Reset
  #define TermList_Get_Term_Num Kino_TermList_Get_Term_Num
  #define TermList_Get_Term Kino_TermList_Get_Term
  #define TermList_Build_Sort_Cache Kino_TermList_Build_Sort_Cache
  #define TERMLIST KINO_TERMLIST
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_TERMLIST_MEMBER_VARS \
    kino_u32_t  refcount


#ifdef KINO_WANT_TERMLIST_VTABLE
KINO_TERMLIST_VTABLE KINO_TERMLIST = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Index::TermList",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Obj_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_TermList_seek_t)kino_TermList_seek,
    (kino_TermList_next_t)kino_TermList_next,
    (kino_TermList_reset_t)kino_TermList_reset,
    (kino_TermList_get_term_num_t)kino_TermList_get_term_num,
    (kino_TermList_get_term_t)kino_TermList_get_term,
    (kino_TermList_build_sort_cache_t)kino_TermList_build_sort_cache
};
#endif /* KINO_WANT_TERMLIST_VTABLE */

#endif /* R_KINO_TERMLIST */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
