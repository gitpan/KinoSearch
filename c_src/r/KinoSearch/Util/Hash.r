/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_HASH
#define R_KINO_HASH 1

#include "KinoSearch/Util/Hash.h"

typedef void
(*kino_Hash_destroy_t)(kino_Hash *self);

typedef void
(*kino_Hash_clear_t)(kino_Hash *self);

typedef void
(*kino_Hash_store_t)(kino_Hash *self, const char *str, size_t len, 
                    kino_Obj *value);

typedef void
(*kino_Hash_store_bb_t)(kino_Hash *self, const kino_ByteBuf *key, kino_Obj *value);

typedef void
(*kino_Hash_store_i64_t)(kino_Hash *self, const char *str, size_t key_len, 
                        kino_i64_t num);

typedef kino_Obj*
(*kino_Hash_fetch_bb_t)(kino_Hash *self, const kino_ByteBuf *key);

typedef kino_Obj*
(*kino_Hash_fetch_t)(kino_Hash *self, const char *key, size_t key_len);

typedef kino_i64_t
(*kino_Hash_fetch_i64_t)(kino_Hash *self, const char *key, size_t key_len);

typedef kino_bool_t
(*kino_Hash_delete_bb_t)(kino_Hash *self, const kino_ByteBuf *key);

typedef kino_bool_t
(*kino_Hash_delete_t)(kino_Hash *self, const char *key, size_t key_ley);

typedef void
(*kino_Hash_iter_init_t)(kino_Hash *self);

typedef kino_bool_t
(*kino_Hash_iter_next_t)(kino_Hash *self, kino_ByteBuf **key, kino_Obj **value);

typedef struct kino_VArray*
(*kino_Hash_keys_t)(kino_Hash *self);

#define Kino_Hash_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_Hash_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_Hash_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_Hash_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_Hash_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_Hash_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_Hash_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_Hash_Clear(_self) \
    (_self)->_->clear((kino_Hash*)_self)

#define Kino_Hash_Store(_self, _arg1, _arg2, _arg3) \
    (_self)->_->store((kino_Hash*)_self, _arg1, _arg2, _arg3)

#define Kino_Hash_Store_BB(_self, _arg1, _arg2) \
    (_self)->_->store_bb((kino_Hash*)_self, _arg1, _arg2)

#define Kino_Hash_Store_I64(_self, _arg1, _arg2, _arg3) \
    (_self)->_->store_i64((kino_Hash*)_self, _arg1, _arg2, _arg3)

#define Kino_Hash_Fetch_BB(_self, _arg1) \
    (_self)->_->fetch_bb((kino_Hash*)_self, _arg1)

#define Kino_Hash_Fetch(_self, _arg1, _arg2) \
    (_self)->_->fetch((kino_Hash*)_self, _arg1, _arg2)

#define Kino_Hash_Fetch_I64(_self, _arg1, _arg2) \
    (_self)->_->fetch_i64((kino_Hash*)_self, _arg1, _arg2)

#define Kino_Hash_Delete_BB(_self, _arg1) \
    (_self)->_->delete_bb((kino_Hash*)_self, _arg1)

#define Kino_Hash_Delete(_self, _arg1, _arg2) \
    (_self)->_->delete((kino_Hash*)_self, _arg1, _arg2)

#define Kino_Hash_Iter_Init(_self) \
    (_self)->_->iter_init((kino_Hash*)_self)

#define Kino_Hash_Iter_Next(_self, _arg1, _arg2) \
    (_self)->_->iter_next((kino_Hash*)_self, _arg1, _arg2)

#define Kino_Hash_Keys(_self) \
    (_self)->_->keys((kino_Hash*)_self)

struct KINO_HASH_VTABLE {
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
    kino_Hash_clear_t clear;
    kino_Hash_store_t store;
    kino_Hash_store_bb_t store_bb;
    kino_Hash_store_i64_t store_i64;
    kino_Hash_fetch_bb_t fetch_bb;
    kino_Hash_fetch_t fetch;
    kino_Hash_fetch_i64_t fetch_i64;
    kino_Hash_delete_bb_t delete_bb;
    kino_Hash_delete_t delete;
    kino_Hash_iter_init_t iter_init;
    kino_Hash_iter_next_t iter_next;
    kino_Hash_keys_t keys;
};

extern KINO_HASH_VTABLE KINO_HASH;

#ifdef KINO_USE_SHORT_NAMES
  #define Hash kino_Hash
  #define HASH KINO_HASH
  #define Hash_new kino_Hash_new
  #define Hash_destroy kino_Hash_destroy
  #define Hash_clear_t kino_Hash_clear_t
  #define Hash_clear kino_Hash_clear
  #define Hash_store_t kino_Hash_store_t
  #define Hash_store kino_Hash_store
  #define Hash_store_bb_t kino_Hash_store_bb_t
  #define Hash_store_bb kino_Hash_store_bb
  #define Hash_store_i64_t kino_Hash_store_i64_t
  #define Hash_store_i64 kino_Hash_store_i64
  #define Hash_fetch_bb_t kino_Hash_fetch_bb_t
  #define Hash_fetch_bb kino_Hash_fetch_bb
  #define Hash_fetch_t kino_Hash_fetch_t
  #define Hash_fetch kino_Hash_fetch
  #define Hash_fetch_i64_t kino_Hash_fetch_i64_t
  #define Hash_fetch_i64 kino_Hash_fetch_i64
  #define Hash_delete_bb_t kino_Hash_delete_bb_t
  #define Hash_delete_bb kino_Hash_delete_bb
  #define Hash_delete_t kino_Hash_delete_t
  #define Hash_delete kino_Hash_delete
  #define Hash_iter_init_t kino_Hash_iter_init_t
  #define Hash_iter_init kino_Hash_iter_init
  #define Hash_iter_next_t kino_Hash_iter_next_t
  #define Hash_iter_next kino_Hash_iter_next
  #define Hash_keys_t kino_Hash_keys_t
  #define Hash_keys kino_Hash_keys
  #define Hash_Clone Kino_Hash_Clone
  #define Hash_Destroy Kino_Hash_Destroy
  #define Hash_Equals Kino_Hash_Equals
  #define Hash_Hash_Code Kino_Hash_Hash_Code
  #define Hash_Is_A Kino_Hash_Is_A
  #define Hash_To_String Kino_Hash_To_String
  #define Hash_Serialize Kino_Hash_Serialize
  #define Hash_Clear Kino_Hash_Clear
  #define Hash_Store Kino_Hash_Store
  #define Hash_Store_BB Kino_Hash_Store_BB
  #define Hash_Store_I64 Kino_Hash_Store_I64
  #define Hash_Fetch_BB Kino_Hash_Fetch_BB
  #define Hash_Fetch Kino_Hash_Fetch
  #define Hash_Fetch_I64 Kino_Hash_Fetch_I64
  #define Hash_Delete_BB Kino_Hash_Delete_BB
  #define Hash_Delete Kino_Hash_Delete
  #define Hash_Iter_Init Kino_Hash_Iter_Init
  #define Hash_Iter_Next Kino_Hash_Iter_Next
  #define Hash_Keys Kino_Hash_Keys
  #define HASH KINO_HASH
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_HASH_MEMBER_VARS \
    struct kino_HashEntry ** buckets; \
    kino_u32_t  num_buckets; \
    kino_u32_t  size; \
    kino_u32_t  threshold; \
    struct kino_HashEntry * next_entry; \
    kino_u32_t  iter_bucket;


#ifdef KINO_WANT_HASH_VTABLE
KINO_HASH_VTABLE KINO_HASH = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Util::Hash",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Hash_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_Hash_clear_t)kino_Hash_clear,
    (kino_Hash_store_t)kino_Hash_store,
    (kino_Hash_store_bb_t)kino_Hash_store_bb,
    (kino_Hash_store_i64_t)kino_Hash_store_i64,
    (kino_Hash_fetch_bb_t)kino_Hash_fetch_bb,
    (kino_Hash_fetch_t)kino_Hash_fetch,
    (kino_Hash_fetch_i64_t)kino_Hash_fetch_i64,
    (kino_Hash_delete_bb_t)kino_Hash_delete_bb,
    (kino_Hash_delete_t)kino_Hash_delete,
    (kino_Hash_iter_init_t)kino_Hash_iter_init,
    (kino_Hash_iter_next_t)kino_Hash_iter_next,
    (kino_Hash_keys_t)kino_Hash_keys
};
#endif /* KINO_WANT_HASH_VTABLE */

#endif /* R_KINO_HASH */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
