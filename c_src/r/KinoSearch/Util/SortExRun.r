/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_SORTEXRUN
#define R_KINO_SORTEXRUN 1

#include "KinoSearch/Util/SortExRun.h"

#define KINO_SORTEXRUN_BOILERPLATE

typedef chy_u32_t
(*kino_SortExRun_refill_t)(kino_SortExRun *self);

typedef void
(*kino_SortExRun_grow_cache_t)(kino_SortExRun *self, chy_u32_t new_cache_cap);

typedef kino_Obj*
(*kino_SortExRun_peek_last_t)(kino_SortExRun *self);

typedef chy_u32_t
(*kino_SortExRun_prepare_slice_t)(kino_SortExRun *self, kino_Obj *endpost);

typedef kino_Obj**
(*kino_SortExRun_pop_slice_t)(kino_SortExRun *self, chy_u32_t *slice_size);

typedef void
(*kino_SortExRun_clear_cache_t)(kino_SortExRun *self);

#define Kino_SortExRun_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_SortExRun_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_SortExRun_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_SortExRun_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_SortExRun_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_SortExRun_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_SortExRun_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_SortExRun_Refill(self) \
    (self)->_->refill((kino_SortExRun*)self)

#define Kino_SortExRun_Grow_Cache(self, new_cache_cap) \
    (self)->_->grow_cache((kino_SortExRun*)self, new_cache_cap)

#define Kino_SortExRun_Peek_Last(self) \
    kino_SortExRun_peek_last((kino_SortExRun*)self)

#define Kino_SortExRun_Prepare_Slice(self, endpost) \
    kino_SortExRun_prepare_slice((kino_SortExRun*)self, endpost)

#define Kino_SortExRun_Pop_Slice(self, slice_size) \
    kino_SortExRun_pop_slice((kino_SortExRun*)self, slice_size)

#define Kino_SortExRun_Clear_Cache(self) \
    (self)->_->clear_cache((kino_SortExRun*)self)

struct KINO_SORTEXRUN_VTABLE {
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
    kino_SortExRun_refill_t refill;
    kino_SortExRun_grow_cache_t grow_cache;
    kino_SortExRun_peek_last_t peek_last;
    kino_SortExRun_prepare_slice_t prepare_slice;
    kino_SortExRun_pop_slice_t pop_slice;
    kino_SortExRun_clear_cache_t clear_cache;
};

extern KINO_SORTEXRUN_VTABLE KINO_SORTEXRUN;

#ifdef KINO_USE_SHORT_NAMES
  #define SortExRun kino_SortExRun
  #define SORTEXRUN KINO_SORTEXRUN
  #define SortExRun_init_base kino_SortExRun_init_base
  #define SortExRun_refill_t kino_SortExRun_refill_t
  #define SortExRun_refill kino_SortExRun_refill
  #define SortExRun_grow_cache_t kino_SortExRun_grow_cache_t
  #define SortExRun_grow_cache kino_SortExRun_grow_cache
  #define SortExRun_peek_last_t kino_SortExRun_peek_last_t
  #define SortExRun_peek_last kino_SortExRun_peek_last
  #define SortExRun_prepare_slice_t kino_SortExRun_prepare_slice_t
  #define SortExRun_prepare_slice kino_SortExRun_prepare_slice
  #define SortExRun_pop_slice_t kino_SortExRun_pop_slice_t
  #define SortExRun_pop_slice kino_SortExRun_pop_slice
  #define SortExRun_clear_cache_t kino_SortExRun_clear_cache_t
  #define SortExRun_clear_cache kino_SortExRun_clear_cache
  #define SortExRun_Clone Kino_SortExRun_Clone
  #define SortExRun_Destroy Kino_SortExRun_Destroy
  #define SortExRun_Equals Kino_SortExRun_Equals
  #define SortExRun_Hash_Code Kino_SortExRun_Hash_Code
  #define SortExRun_Is_A Kino_SortExRun_Is_A
  #define SortExRun_To_String Kino_SortExRun_To_String
  #define SortExRun_Serialize Kino_SortExRun_Serialize
  #define SortExRun_Refill Kino_SortExRun_Refill
  #define SortExRun_Grow_Cache Kino_SortExRun_Grow_Cache
  #define SortExRun_Peek_Last Kino_SortExRun_Peek_Last
  #define SortExRun_Prepare_Slice Kino_SortExRun_Prepare_Slice
  #define SortExRun_Pop_Slice Kino_SortExRun_Pop_Slice
  #define SortExRun_Clear_Cache Kino_SortExRun_Clear_Cache
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_SORTEXRUN_MEMBER_VARS \
    chy_u32_t  refcount; \
    kino_MSort_compare_t  compare; \
    kino_Obj * context; \
    kino_Obj ** cache; \
    chy_u32_t  cache_cap; \
    chy_u32_t  cache_max; \
    chy_u32_t  cache_tick; \
    chy_u32_t  slice_size

#ifdef KINO_WANT_SORTEXRUN_VTABLE
KINO_SORTEXRUN_VTABLE KINO_SORTEXRUN = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Util::SortExRun",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Obj_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_SortExRun_refill_t)kino_SortExRun_refill,
    (kino_SortExRun_grow_cache_t)kino_SortExRun_grow_cache,
    (kino_SortExRun_peek_last_t)kino_SortExRun_peek_last,
    (kino_SortExRun_prepare_slice_t)kino_SortExRun_prepare_slice,
    (kino_SortExRun_pop_slice_t)kino_SortExRun_pop_slice,
    (kino_SortExRun_clear_cache_t)kino_SortExRun_clear_cache
};
#endif /* KINO_WANT_SORTEXRUN_VTABLE */

#undef KINO_SORTEXRUN_BOILERPLATE


#endif /* R_KINO_SORTEXRUN */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
