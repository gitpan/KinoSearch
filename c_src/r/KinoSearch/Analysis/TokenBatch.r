/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_TOKENBATCH
#define R_KINO_TOKENBATCH 1

#include "KinoSearch/Analysis/TokenBatch.h"

typedef void
(*kino_TokenBatch_destroy_t)(kino_TokenBatch *self);

typedef void
(*kino_TokenBatch_append_t)(kino_TokenBatch *self, struct kino_Token *token);

typedef struct kino_Token*
(*kino_TokenBatch_next_t)(kino_TokenBatch *self);

typedef void
(*kino_TokenBatch_reset_t)(kino_TokenBatch *self);

typedef void
(*kino_TokenBatch_invert_t)(kino_TokenBatch *self);

typedef struct kino_Token**
(*kino_TokenBatch_next_cluster_t)(kino_TokenBatch *self, kino_u32_t *count);

#define Kino_TokenBatch_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_TokenBatch_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_TokenBatch_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_TokenBatch_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_TokenBatch_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_TokenBatch_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_TokenBatch_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_TokenBatch_Push(_self, _arg1) \
    (_self)->_->push((kino_VArray*)_self, _arg1)

#define Kino_TokenBatch_Pop(_self) \
    (_self)->_->pop((kino_VArray*)_self)

#define Kino_TokenBatch_Unshift(_self, _arg1) \
    (_self)->_->unshift((kino_VArray*)_self, _arg1)

#define Kino_TokenBatch_Shift(_self) \
    (_self)->_->shift((kino_VArray*)_self)

#define Kino_TokenBatch_Grow(_self, _arg1) \
    (_self)->_->grow((kino_VArray*)_self, _arg1)

#define Kino_TokenBatch_Fetch(_self, _arg1) \
    (_self)->_->fetch((kino_VArray*)_self, _arg1)

#define Kino_TokenBatch_Store(_self, _arg1, _arg2) \
    (_self)->_->store((kino_VArray*)_self, _arg1, _arg2)

#define Kino_TokenBatch_Append(_self, _arg1) \
    (_self)->_->append((kino_TokenBatch*)_self, _arg1)

#define Kino_TokenBatch_Next(_self) \
    (_self)->_->next((kino_TokenBatch*)_self)

#define Kino_TokenBatch_Reset(_self) \
    (_self)->_->reset((kino_TokenBatch*)_self)

#define Kino_TokenBatch_Invert(_self) \
    (_self)->_->invert((kino_TokenBatch*)_self)

#define Kino_TokenBatch_Next_Cluster(_self, _arg1) \
    (_self)->_->next_cluster((kino_TokenBatch*)_self, _arg1)

struct KINO_TOKENBATCH_VTABLE {
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
    kino_VA_push_t push;
    kino_VA_pop_t pop;
    kino_VA_unshift_t unshift;
    kino_VA_shift_t shift;
    kino_VA_grow_t grow;
    kino_VA_fetch_t fetch;
    kino_VA_store_t store;
    kino_TokenBatch_append_t append;
    kino_TokenBatch_next_t next;
    kino_TokenBatch_reset_t reset;
    kino_TokenBatch_invert_t invert;
    kino_TokenBatch_next_cluster_t next_cluster;
};

extern KINO_TOKENBATCH_VTABLE KINO_TOKENBATCH;

#ifdef KINO_USE_SHORT_NAMES
  #define TokenBatch kino_TokenBatch
  #define TOKENBATCH KINO_TOKENBATCH
  #define TokenBatch_new kino_TokenBatch_new
  #define TokenBatch_destroy kino_TokenBatch_destroy
  #define TokenBatch_append_t kino_TokenBatch_append_t
  #define TokenBatch_append kino_TokenBatch_append
  #define TokenBatch_next_t kino_TokenBatch_next_t
  #define TokenBatch_next kino_TokenBatch_next
  #define TokenBatch_reset_t kino_TokenBatch_reset_t
  #define TokenBatch_reset kino_TokenBatch_reset
  #define TokenBatch_invert_t kino_TokenBatch_invert_t
  #define TokenBatch_invert kino_TokenBatch_invert
  #define TokenBatch_next_cluster_t kino_TokenBatch_next_cluster_t
  #define TokenBatch_next_cluster kino_TokenBatch_next_cluster
  #define TokenBatch_Clone Kino_TokenBatch_Clone
  #define TokenBatch_Destroy Kino_TokenBatch_Destroy
  #define TokenBatch_Equals Kino_TokenBatch_Equals
  #define TokenBatch_Hash_Code Kino_TokenBatch_Hash_Code
  #define TokenBatch_Is_A Kino_TokenBatch_Is_A
  #define TokenBatch_To_String Kino_TokenBatch_To_String
  #define TokenBatch_Serialize Kino_TokenBatch_Serialize
  #define TokenBatch_Push Kino_TokenBatch_Push
  #define TokenBatch_Pop Kino_TokenBatch_Pop
  #define TokenBatch_Unshift Kino_TokenBatch_Unshift
  #define TokenBatch_Shift Kino_TokenBatch_Shift
  #define TokenBatch_Grow Kino_TokenBatch_Grow
  #define TokenBatch_Fetch Kino_TokenBatch_Fetch
  #define TokenBatch_Store Kino_TokenBatch_Store
  #define TokenBatch_Append Kino_TokenBatch_Append
  #define TokenBatch_Next Kino_TokenBatch_Next
  #define TokenBatch_Reset Kino_TokenBatch_Reset
  #define TokenBatch_Invert Kino_TokenBatch_Invert
  #define TokenBatch_Next_Cluster Kino_TokenBatch_Next_Cluster
  #define TOKENBATCH KINO_TOKENBATCH
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_TOKENBATCH_MEMBER_VARS \
    kino_Obj ** elems; \
    kino_u32_t  size; \
    kino_u32_t  cap; \
    kino_u32_t  cur; \
    kino_bool_t  inverted; \
    kino_u32_t * cluster_counts; \
    kino_u32_t  cluster_counts_size;


#ifdef KINO_WANT_TOKENBATCH_VTABLE
KINO_TOKENBATCH_VTABLE KINO_TOKENBATCH = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_VARRAY,
    "KinoSearch::Analysis::TokenBatch",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_TokenBatch_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_VA_push_t)kino_VA_push,
    (kino_VA_pop_t)kino_VA_pop,
    (kino_VA_unshift_t)kino_VA_unshift,
    (kino_VA_shift_t)kino_VA_shift,
    (kino_VA_grow_t)kino_VA_grow,
    (kino_VA_fetch_t)kino_VA_fetch,
    (kino_VA_store_t)kino_VA_store,
    (kino_TokenBatch_append_t)kino_TokenBatch_append,
    (kino_TokenBatch_next_t)kino_TokenBatch_next,
    (kino_TokenBatch_reset_t)kino_TokenBatch_reset,
    (kino_TokenBatch_invert_t)kino_TokenBatch_invert,
    (kino_TokenBatch_next_cluster_t)kino_TokenBatch_next_cluster
};
#endif /* KINO_WANT_TOKENBATCH_VTABLE */

#endif /* R_KINO_TOKENBATCH */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
