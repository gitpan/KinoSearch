/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_TLCACHE
#define R_KINO_TLCACHE 1

#include "KinoSearch/Index/TermListCache.h"

typedef void
(*kino_TLCache_destroy_t)(kino_TermListCache *self);

typedef void
(*kino_TLCache_seek_t)(kino_TermListCache *self, struct kino_Term *term);

typedef kino_i32_t
(*kino_TLCache_get_term_num_t)(kino_TermListCache *self);

typedef struct kino_Term*
(*kino_TLCache_get_term_t)(kino_TermListCache *self);

#define Kino_TLCache_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_TLCache_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_TLCache_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_TLCache_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_TLCache_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_TLCache_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_TLCache_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_TLCache_Seek(_self, _arg1) \
    (_self)->_->seek((kino_TermList*)_self, _arg1)

#define Kino_TLCache_Next(_self) \
    (_self)->_->next((kino_TermList*)_self)

#define Kino_TLCache_Reset(_self) \
    (_self)->_->reset((kino_TermList*)_self)

#define Kino_TLCache_Get_Term_Num(_self) \
    (_self)->_->get_term_num((kino_TermList*)_self)

#define Kino_TLCache_Get_Term(_self) \
    (_self)->_->get_term((kino_TermList*)_self)

#define Kino_TLCache_Build_Sort_Cache(_self, _arg1, _arg2) \
    (_self)->_->build_sort_cache((kino_TermList*)_self, _arg1, _arg2)

struct KINO_TERMLISTCACHE_VTABLE {
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

extern KINO_TERMLISTCACHE_VTABLE KINO_TERMLISTCACHE;

#ifdef KINO_USE_SHORT_NAMES
  #define TermListCache kino_TermListCache
  #define TERMLISTCACHE KINO_TERMLISTCACHE
  #define TLCache_new kino_TLCache_new
  #define TLCache_destroy kino_TLCache_destroy
  #define TLCache_seek kino_TLCache_seek
  #define TLCache_get_term_num kino_TLCache_get_term_num
  #define TLCache_get_term kino_TLCache_get_term
  #define TLCache_Clone Kino_TLCache_Clone
  #define TLCache_Destroy Kino_TLCache_Destroy
  #define TLCache_Equals Kino_TLCache_Equals
  #define TLCache_Hash_Code Kino_TLCache_Hash_Code
  #define TLCache_Is_A Kino_TLCache_Is_A
  #define TLCache_To_String Kino_TLCache_To_String
  #define TLCache_Serialize Kino_TLCache_Serialize
  #define TLCache_Seek Kino_TLCache_Seek
  #define TLCache_Next Kino_TLCache_Next
  #define TLCache_Reset Kino_TLCache_Reset
  #define TLCache_Get_Term_Num Kino_TLCache_Get_Term_Num
  #define TLCache_Get_Term Kino_TLCache_Get_Term
  #define TLCache_Build_Sort_Cache Kino_TLCache_Build_Sort_Cache
  #define TERMLISTCACHE KINO_TERMLISTCACHE
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_TERMLISTCACHE_MEMBER_VARS \
    struct kino_ByteBuf ** term_texts; \
    struct kino_Term * term; \
    struct kino_ByteBuf * field; \
    kino_i32_t  tick; \
    kino_i32_t  size; \
    kino_i32_t  index_interval;


#ifdef KINO_WANT_TERMLISTCACHE_VTABLE
KINO_TERMLISTCACHE_VTABLE KINO_TERMLISTCACHE = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_TERMLIST,
    "KinoSearch::Index::TermListCache",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_TLCache_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_TermList_seek_t)kino_TLCache_seek,
    (kino_TermList_next_t)kino_TermList_next,
    (kino_TermList_reset_t)kino_TermList_reset,
    (kino_TermList_get_term_num_t)kino_TLCache_get_term_num,
    (kino_TermList_get_term_t)kino_TLCache_get_term,
    (kino_TermList_build_sort_cache_t)kino_TermList_build_sort_cache
};
#endif /* KINO_WANT_TERMLISTCACHE_VTABLE */

#endif /* R_KINO_TLCACHE */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
