/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_BITVECTOR
#define R_KINO_BITVECTOR 1

#include "KinoSearch/Util/BitVector.h"

#define KINO_BITVECTOR_BOILERPLATE

typedef kino_BitVector*
(*kino_BitVec_clone_t)(kino_BitVector *self);

typedef void
(*kino_BitVec_destroy_t)(kino_BitVector* self);

typedef chy_bool_t
(*kino_BitVec_get_t)(const kino_BitVector *self, chy_u32_t num);

typedef void
(*kino_BitVec_set_t)(kino_BitVector *self, chy_u32_t num);

typedef void
(*kino_BitVec_clear_t)(kino_BitVector *self, chy_u32_t num);

typedef void
(*kino_BitVec_grow_t)(kino_BitVector *self, chy_u32_t capacity);

typedef void
(*kino_BitVec_and_t)(kino_BitVector *self, kino_BitVector *other);

typedef void
(*kino_BitVec_or_t)(kino_BitVector *self, kino_BitVector *other);

typedef void
(*kino_BitVec_xor_t)(kino_BitVector *self, kino_BitVector *other);

typedef void
(*kino_BitVec_and_not_t)(kino_BitVector *self, kino_BitVector *other);

typedef void
(*kino_BitVec_flip_t)(kino_BitVector *self, chy_u32_t num);

typedef void
(*kino_BitVec_flip_range_t)(kino_BitVector *self, chy_u32_t from_tick, 
                       chy_u32_t to_tick);

typedef chy_u32_t
(*kino_BitVec_count_t)(kino_BitVector *self);

typedef chy_u32_t*
(*kino_BitVec_to_array_t)(kino_BitVector *self);

#define Kino_BitVec_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_BitVec_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_BitVec_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_BitVec_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_BitVec_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_BitVec_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_BitVec_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_BitVec_Get(self, num) \
    (self)->_->get((kino_BitVector*)self, num)

#define Kino_BitVec_Set(self, num) \
    (self)->_->set((kino_BitVector*)self, num)

#define Kino_BitVec_Clear(self, num) \
    (self)->_->clear((kino_BitVector*)self, num)

#define Kino_BitVec_Grow(self, capacity) \
    (self)->_->grow((kino_BitVector*)self, capacity)

#define Kino_BitVec_And(self, other) \
    (self)->_->and((kino_BitVector*)self, other)

#define Kino_BitVec_Or(self, other) \
    (self)->_->or((kino_BitVector*)self, other)

#define Kino_BitVec_Xor(self, other) \
    (self)->_->xor((kino_BitVector*)self, other)

#define Kino_BitVec_And_Not(self, other) \
    (self)->_->and_not((kino_BitVector*)self, other)

#define Kino_BitVec_Flip(self, num) \
    (self)->_->flip((kino_BitVector*)self, num)

#define Kino_BitVec_Flip_Range(self, from_tick, to_tick) \
    (self)->_->flip_range((kino_BitVector*)self, from_tick, to_tick)

#define Kino_BitVec_Count(self) \
    (self)->_->count((kino_BitVector*)self)

#define Kino_BitVec_To_Array(self) \
    (self)->_->to_array((kino_BitVector*)self)

struct KINO_BITVECTOR_VTABLE {
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
    kino_BitVec_get_t get;
    kino_BitVec_set_t set;
    kino_BitVec_clear_t clear;
    kino_BitVec_grow_t grow;
    kino_BitVec_and_t and;
    kino_BitVec_or_t or;
    kino_BitVec_xor_t xor;
    kino_BitVec_and_not_t and_not;
    kino_BitVec_flip_t flip;
    kino_BitVec_flip_range_t flip_range;
    kino_BitVec_count_t count;
    kino_BitVec_to_array_t to_array;
};

extern KINO_BITVECTOR_VTABLE KINO_BITVECTOR;

#ifdef KINO_USE_SHORT_NAMES
  #define BitVector kino_BitVector
  #define BITVECTOR KINO_BITVECTOR
  #define BitVec_new kino_BitVec_new
  #define BitVec_init_base kino_BitVec_init_base
  #define BitVec_clone kino_BitVec_clone
  #define BitVec_destroy kino_BitVec_destroy
  #define BitVec_get_t kino_BitVec_get_t
  #define BitVec_get kino_BitVec_get
  #define BitVec_set_t kino_BitVec_set_t
  #define BitVec_set kino_BitVec_set
  #define BitVec_clear_t kino_BitVec_clear_t
  #define BitVec_clear kino_BitVec_clear
  #define BitVec_grow_t kino_BitVec_grow_t
  #define BitVec_grow kino_BitVec_grow
  #define BitVec_and_t kino_BitVec_and_t
  #define BitVec_and kino_BitVec_and
  #define BitVec_or_t kino_BitVec_or_t
  #define BitVec_or kino_BitVec_or
  #define BitVec_xor_t kino_BitVec_xor_t
  #define BitVec_xor kino_BitVec_xor
  #define BitVec_and_not_t kino_BitVec_and_not_t
  #define BitVec_and_not kino_BitVec_and_not
  #define BitVec_flip_t kino_BitVec_flip_t
  #define BitVec_flip kino_BitVec_flip
  #define BitVec_flip_range_t kino_BitVec_flip_range_t
  #define BitVec_flip_range kino_BitVec_flip_range
  #define BitVec_count_t kino_BitVec_count_t
  #define BitVec_count kino_BitVec_count
  #define BitVec_to_array_t kino_BitVec_to_array_t
  #define BitVec_to_array kino_BitVec_to_array
  #define BitVec_Clone Kino_BitVec_Clone
  #define BitVec_Destroy Kino_BitVec_Destroy
  #define BitVec_Equals Kino_BitVec_Equals
  #define BitVec_Hash_Code Kino_BitVec_Hash_Code
  #define BitVec_Is_A Kino_BitVec_Is_A
  #define BitVec_To_String Kino_BitVec_To_String
  #define BitVec_Serialize Kino_BitVec_Serialize
  #define BitVec_Get Kino_BitVec_Get
  #define BitVec_Set Kino_BitVec_Set
  #define BitVec_Clear Kino_BitVec_Clear
  #define BitVec_Grow Kino_BitVec_Grow
  #define BitVec_And Kino_BitVec_And
  #define BitVec_Or Kino_BitVec_Or
  #define BitVec_Xor Kino_BitVec_Xor
  #define BitVec_And_Not Kino_BitVec_And_Not
  #define BitVec_Flip Kino_BitVec_Flip
  #define BitVec_Flip_Range Kino_BitVec_Flip_Range
  #define BitVec_Count Kino_BitVec_Count
  #define BitVec_To_Array Kino_BitVec_To_Array
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_BITVECTOR_MEMBER_VARS \
    chy_u32_t  refcount; \
    chy_u32_t  cap; \
    chy_u8_t * bits; \
    chy_u32_t  count

#ifdef KINO_WANT_BITVECTOR_VTABLE
KINO_BITVECTOR_VTABLE KINO_BITVECTOR = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Util::BitVector",
    (kino_Obj_clone_t)kino_BitVec_clone,
    (kino_Obj_destroy_t)kino_BitVec_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_BitVec_get_t)kino_BitVec_get,
    (kino_BitVec_set_t)kino_BitVec_set,
    (kino_BitVec_clear_t)kino_BitVec_clear,
    (kino_BitVec_grow_t)kino_BitVec_grow,
    (kino_BitVec_and_t)kino_BitVec_and,
    (kino_BitVec_or_t)kino_BitVec_or,
    (kino_BitVec_xor_t)kino_BitVec_xor,
    (kino_BitVec_and_not_t)kino_BitVec_and_not,
    (kino_BitVec_flip_t)kino_BitVec_flip,
    (kino_BitVec_flip_range_t)kino_BitVec_flip_range,
    (kino_BitVec_count_t)kino_BitVec_count,
    (kino_BitVec_to_array_t)kino_BitVec_to_array
};
#endif /* KINO_WANT_BITVECTOR_VTABLE */

#undef KINO_BITVECTOR_BOILERPLATE


#endif /* R_KINO_BITVECTOR */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

