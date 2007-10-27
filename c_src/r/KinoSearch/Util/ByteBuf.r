/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_BYTEBUF
#define R_KINO_BYTEBUF 1

#include "KinoSearch/Util/ByteBuf.h"

#define KINO_BYTEBUF_BOILERPLATE

typedef kino_ByteBuf*
(*kino_BB_clone_t)(kino_ByteBuf *self);

typedef void
(*kino_BB_destroy_t)(kino_ByteBuf *self);

typedef chy_bool_t
(*kino_BB_equals_t)(kino_ByteBuf *self, kino_ByteBuf *other);

typedef chy_i32_t
(*kino_BB_hash_code_t)(kino_ByteBuf *self);

typedef kino_ByteBuf*
(*kino_BB_to_string_t)(kino_ByteBuf *self);

typedef void
(*kino_BB_serialize_t)(kino_ByteBuf *self, kino_ByteBuf *target);

typedef void
(*kino_BB_copy_str_t)(kino_ByteBuf *self, char* ptr, size_t size);

typedef void
(*kino_BB_copy_bb_t)(kino_ByteBuf *self, const kino_ByteBuf *other);

typedef void
(*kino_BB_cat_str_t)(kino_ByteBuf *self, char* ptr, size_t size);

typedef void
(*kino_BB_cat_bb_t)(kino_ByteBuf *self, const kino_ByteBuf *other);

typedef void
(*kino_BB_cat_i64_t)(kino_ByteBuf *self, chy_i64_t num);

typedef chy_i64_t
(*kino_BB_to_i64_t)(kino_ByteBuf *self);

typedef void
(*kino_BB_grow_t)(kino_ByteBuf *self, size_t new_size);

typedef chy_bool_t
(*kino_BB_starts_with_t)(kino_ByteBuf *self, const kino_ByteBuf *prefix);

typedef chy_bool_t
(*kino_BB_ends_with_str_t)(kino_ByteBuf *self, const char *postfix, 
                      size_t postfix_len);

#define Kino_BB_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_BB_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_BB_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_BB_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_BB_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_BB_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_BB_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_BB_Copy_Str(self, ptr, size) \
    (self)->_->copy_str((kino_ByteBuf*)self, ptr, size)

#define Kino_BB_Copy_BB(self, other) \
    (self)->_->copy_bb((kino_ByteBuf*)self, other)

#define Kino_BB_Cat_Str(self, ptr, size) \
    (self)->_->cat_str((kino_ByteBuf*)self, ptr, size)

#define Kino_BB_Cat_BB(self, other) \
    (self)->_->cat_bb((kino_ByteBuf*)self, other)

#define Kino_BB_Cat_I64(self, num) \
    (self)->_->cat_i64((kino_ByteBuf*)self, num)

#define Kino_BB_To_I64(self) \
    (self)->_->to_i64((kino_ByteBuf*)self)

#define Kino_BB_Grow(self, new_size) \
    (self)->_->grow((kino_ByteBuf*)self, new_size)

#define Kino_BB_Starts_With(self, prefix) \
    (self)->_->starts_with((kino_ByteBuf*)self, prefix)

#define Kino_BB_Ends_With_Str(self, postfix, postfix_len) \
    (self)->_->ends_with_str((kino_ByteBuf*)self, postfix, postfix_len)

struct KINO_BYTEBUF_VTABLE {
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
    kino_BB_copy_str_t copy_str;
    kino_BB_copy_bb_t copy_bb;
    kino_BB_cat_str_t cat_str;
    kino_BB_cat_bb_t cat_bb;
    kino_BB_cat_i64_t cat_i64;
    kino_BB_to_i64_t to_i64;
    kino_BB_grow_t grow;
    kino_BB_starts_with_t starts_with;
    kino_BB_ends_with_str_t ends_with_str;
};

extern KINO_BYTEBUF_VTABLE KINO_BYTEBUF;

#ifdef KINO_USE_SHORT_NAMES
  #define ByteBuf kino_ByteBuf
  #define BYTEBUF KINO_BYTEBUF
  #define BB_new kino_BB_new
  #define BB_new_str kino_BB_new_str
  #define BB_new_steal kino_BB_new_steal
  #define BB_new_i64 kino_BB_new_i64
  #define BB_compare kino_BB_compare
  #define BB_less_than kino_BB_less_than
  #define BB_deserialize kino_BB_deserialize
  #define BB_clone kino_BB_clone
  #define BB_destroy kino_BB_destroy
  #define BB_equals kino_BB_equals
  #define BB_hash_code kino_BB_hash_code
  #define BB_to_string kino_BB_to_string
  #define BB_serialize kino_BB_serialize
  #define BB_copy_str_t kino_BB_copy_str_t
  #define BB_copy_str kino_BB_copy_str
  #define BB_copy_bb_t kino_BB_copy_bb_t
  #define BB_copy_bb kino_BB_copy_bb
  #define BB_cat_str_t kino_BB_cat_str_t
  #define BB_cat_str kino_BB_cat_str
  #define BB_cat_bb_t kino_BB_cat_bb_t
  #define BB_cat_bb kino_BB_cat_bb
  #define BB_cat_i64_t kino_BB_cat_i64_t
  #define BB_cat_i64 kino_BB_cat_i64
  #define BB_to_i64_t kino_BB_to_i64_t
  #define BB_to_i64 kino_BB_to_i64
  #define BB_grow_t kino_BB_grow_t
  #define BB_grow kino_BB_grow
  #define BB_starts_with_t kino_BB_starts_with_t
  #define BB_starts_with kino_BB_starts_with
  #define BB_ends_with_str_t kino_BB_ends_with_str_t
  #define BB_ends_with_str kino_BB_ends_with_str
  #define BB_Clone Kino_BB_Clone
  #define BB_Destroy Kino_BB_Destroy
  #define BB_Equals Kino_BB_Equals
  #define BB_Hash_Code Kino_BB_Hash_Code
  #define BB_Is_A Kino_BB_Is_A
  #define BB_To_String Kino_BB_To_String
  #define BB_Serialize Kino_BB_Serialize
  #define BB_Copy_Str Kino_BB_Copy_Str
  #define BB_Copy_BB Kino_BB_Copy_BB
  #define BB_Cat_Str Kino_BB_Cat_Str
  #define BB_Cat_BB Kino_BB_Cat_BB
  #define BB_Cat_I64 Kino_BB_Cat_I64
  #define BB_To_I64 Kino_BB_To_I64
  #define BB_Grow Kino_BB_Grow
  #define BB_Starts_With Kino_BB_Starts_With
  #define BB_Ends_With_Str Kino_BB_Ends_With_Str
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_BYTEBUF_MEMBER_VARS \
    chy_u32_t  refcount; \
    char * ptr; \
    size_t  len; \
    size_t  cap

#ifdef KINO_WANT_BYTEBUF_VTABLE
KINO_BYTEBUF_VTABLE KINO_BYTEBUF = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Util::ByteBuf",
    (kino_Obj_clone_t)kino_BB_clone,
    (kino_Obj_destroy_t)kino_BB_destroy,
    (kino_Obj_equals_t)kino_BB_equals,
    (kino_Obj_hash_code_t)kino_BB_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_BB_to_string,
    (kino_Obj_serialize_t)kino_BB_serialize,
    (kino_BB_copy_str_t)kino_BB_copy_str,
    (kino_BB_copy_bb_t)kino_BB_copy_bb,
    (kino_BB_cat_str_t)kino_BB_cat_str,
    (kino_BB_cat_bb_t)kino_BB_cat_bb,
    (kino_BB_cat_i64_t)kino_BB_cat_i64,
    (kino_BB_to_i64_t)kino_BB_to_i64,
    (kino_BB_grow_t)kino_BB_grow,
    (kino_BB_starts_with_t)kino_BB_starts_with,
    (kino_BB_ends_with_str_t)kino_BB_ends_with_str
};
#endif /* KINO_WANT_BYTEBUF_VTABLE */

#undef KINO_BYTEBUF_BOILERPLATE


#endif /* R_KINO_BYTEBUF */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

