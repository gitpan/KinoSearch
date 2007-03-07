/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_VIEWBB
#define R_KINO_VIEWBB 1

#include "KinoSearch/Util/ViewByteBuf.h"

typedef void
(*kino_ViewBB_destroy_t)(kino_ViewByteBuf *self);

typedef void
(*kino_ViewBB_assign_t)(kino_ViewByteBuf *self, char*ptr, size_t size);

#define Kino_ViewBB_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_ViewBB_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_ViewBB_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_ViewBB_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_ViewBB_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_ViewBB_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_ViewBB_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_ViewBB_Copy_Str(_self, _arg1, _arg2) \
    (_self)->_->copy_str((kino_ByteBuf*)_self, _arg1, _arg2)

#define Kino_ViewBB_Copy_BB(_self, _arg1) \
    (_self)->_->copy_bb((kino_ByteBuf*)_self, _arg1)

#define Kino_ViewBB_Cat_Str(_self, _arg1, _arg2) \
    (_self)->_->cat_str((kino_ByteBuf*)_self, _arg1, _arg2)

#define Kino_ViewBB_Cat_BB(_self, _arg1) \
    (_self)->_->cat_bb((kino_ByteBuf*)_self, _arg1)

#define Kino_ViewBB_Cat_I64(_self, _arg1) \
    (_self)->_->cat_i64((kino_ByteBuf*)_self, _arg1)

#define Kino_ViewBB_To_I64(_self) \
    (_self)->_->to_i64((kino_ByteBuf*)_self)

#define Kino_ViewBB_Grow(_self, _arg1) \
    (_self)->_->grow((kino_ByteBuf*)_self, _arg1)

#define Kino_ViewBB_Assign(_self, _arg1, _arg2) \
    (_self)->_->assign((kino_ViewByteBuf*)_self, _arg1, _arg2)

struct KINO_VIEWBYTEBUF_VTABLE {
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
    kino_BB_copy_str_t copy_str;
    kino_BB_copy_bb_t copy_bb;
    kino_BB_cat_str_t cat_str;
    kino_BB_cat_bb_t cat_bb;
    kino_BB_cat_i64_t cat_i64;
    kino_BB_to_i64_t to_i64;
    kino_BB_grow_t grow;
    kino_ViewBB_assign_t assign;
};

extern KINO_VIEWBYTEBUF_VTABLE KINO_VIEWBYTEBUF;

#ifdef KINO_USE_SHORT_NAMES
  #define ViewByteBuf kino_ViewByteBuf
  #define VIEWBYTEBUF KINO_VIEWBYTEBUF
  #define ViewBB_new kino_ViewBB_new
  #define ViewBB_destroy kino_ViewBB_destroy
  #define ViewBB_assign_t kino_ViewBB_assign_t
  #define ViewBB_assign kino_ViewBB_assign
  #define ViewBB_Clone Kino_ViewBB_Clone
  #define ViewBB_Destroy Kino_ViewBB_Destroy
  #define ViewBB_Equals Kino_ViewBB_Equals
  #define ViewBB_Hash_Code Kino_ViewBB_Hash_Code
  #define ViewBB_Is_A Kino_ViewBB_Is_A
  #define ViewBB_To_String Kino_ViewBB_To_String
  #define ViewBB_Serialize Kino_ViewBB_Serialize
  #define ViewBB_Copy_Str Kino_ViewBB_Copy_Str
  #define ViewBB_Copy_BB Kino_ViewBB_Copy_BB
  #define ViewBB_Cat_Str Kino_ViewBB_Cat_Str
  #define ViewBB_Cat_BB Kino_ViewBB_Cat_BB
  #define ViewBB_Cat_I64 Kino_ViewBB_Cat_I64
  #define ViewBB_To_I64 Kino_ViewBB_To_I64
  #define ViewBB_Grow Kino_ViewBB_Grow
  #define ViewBB_Assign Kino_ViewBB_Assign
  #define VIEWBYTEBUF KINO_VIEWBYTEBUF
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_VIEWBYTEBUF_MEMBER_VARS \
    kino_u32_t  refcount; \
    char * ptr; \
    size_t  len; \
    size_t  cap; \
    char * ptr; \
    size_t  len; \
    size_t  cap


#ifdef KINO_WANT_VIEWBYTEBUF_VTABLE
KINO_VIEWBYTEBUF_VTABLE KINO_VIEWBYTEBUF = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_BYTEBUF,
    "KinoSearch::Util::ViewByteBuf",
    (kino_Obj_clone_t)kino_BB_clone,
    (kino_Obj_destroy_t)kino_ViewBB_destroy,
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
    (kino_ViewBB_assign_t)kino_ViewBB_assign
};
#endif /* KINO_WANT_VIEWBYTEBUF_VTABLE */

#endif /* R_KINO_VIEWBB */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */