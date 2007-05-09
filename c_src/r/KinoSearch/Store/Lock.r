/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_LOCK
#define R_KINO_LOCK 1

#include "KinoSearch/Store/Lock.h"

#define KINO_LOCK_BOILERPLATE

typedef void
(*kino_Lock_destroy_t)(kino_Lock *self);

typedef chy_bool_t
(*kino_Lock_obtain_t)(kino_Lock *self);

typedef chy_bool_t
(*kino_Lock_do_obtain_t)(kino_Lock *self);

typedef void
(*kino_Lock_release_t)(kino_Lock *self);

typedef chy_bool_t
(*kino_Lock_is_locked_t)(kino_Lock *self);

typedef void
(*kino_Lock_clear_stale_t)(kino_Lock *self);

#define Kino_Lock_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_Lock_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_Lock_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_Lock_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_Lock_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_Lock_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_Lock_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_Lock_Obtain(self) \
    (self)->_->obtain((kino_Lock*)self)

#define Kino_Lock_Do_Obtain(self) \
    (self)->_->do_obtain((kino_Lock*)self)

#define Kino_Lock_Release(self) \
    (self)->_->release((kino_Lock*)self)

#define Kino_Lock_Is_Locked(self) \
    (self)->_->is_locked((kino_Lock*)self)

#define Kino_Lock_Clear_Stale(self) \
    (self)->_->clear_stale((kino_Lock*)self)

struct KINO_LOCK_VTABLE {
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
    kino_Lock_obtain_t obtain;
    kino_Lock_do_obtain_t do_obtain;
    kino_Lock_release_t release;
    kino_Lock_is_locked_t is_locked;
    kino_Lock_clear_stale_t clear_stale;
};

extern KINO_LOCK_VTABLE KINO_LOCK;

#ifdef KINO_USE_SHORT_NAMES
  #define Lock kino_Lock
  #define LOCK KINO_LOCK
  #define Lock_new kino_Lock_new
  #define Lock_destroy kino_Lock_destroy
  #define Lock_obtain_t kino_Lock_obtain_t
  #define Lock_obtain kino_Lock_obtain
  #define Lock_do_obtain_t kino_Lock_do_obtain_t
  #define Lock_do_obtain kino_Lock_do_obtain
  #define Lock_release_t kino_Lock_release_t
  #define Lock_release kino_Lock_release
  #define Lock_is_locked_t kino_Lock_is_locked_t
  #define Lock_is_locked kino_Lock_is_locked
  #define Lock_clear_stale_t kino_Lock_clear_stale_t
  #define Lock_clear_stale kino_Lock_clear_stale
  #define Lock_Clone Kino_Lock_Clone
  #define Lock_Destroy Kino_Lock_Destroy
  #define Lock_Equals Kino_Lock_Equals
  #define Lock_Hash_Code Kino_Lock_Hash_Code
  #define Lock_Is_A Kino_Lock_Is_A
  #define Lock_To_String Kino_Lock_To_String
  #define Lock_Serialize Kino_Lock_Serialize
  #define Lock_Obtain Kino_Lock_Obtain
  #define Lock_Do_Obtain Kino_Lock_Do_Obtain
  #define Lock_Release Kino_Lock_Release
  #define Lock_Is_Locked Kino_Lock_Is_Locked
  #define Lock_Clear_Stale Kino_Lock_Clear_Stale
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_LOCK_MEMBER_VARS \
    chy_u32_t  refcount; \
    struct kino_Folder * folder; \
    struct kino_ByteBuf * lock_name; \
    struct kino_ByteBuf * filename; \
    struct kino_ByteBuf * agent_id; \
    chy_i32_t  timeout

#ifdef KINO_WANT_LOCK_VTABLE
KINO_LOCK_VTABLE KINO_LOCK = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Store::Lock",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Lock_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_Lock_obtain_t)kino_Lock_obtain,
    (kino_Lock_do_obtain_t)kino_Lock_do_obtain,
    (kino_Lock_release_t)kino_Lock_release,
    (kino_Lock_is_locked_t)kino_Lock_is_locked,
    (kino_Lock_clear_stale_t)kino_Lock_clear_stale
};
#endif /* KINO_WANT_LOCK_VTABLE */

#undef KINO_LOCK_BOILERPLATE


#endif /* R_KINO_LOCK */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

