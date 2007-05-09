/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_LEXREADER
#define R_KINO_LEXREADER 1

#include "KinoSearch/Index/LexReader.h"

#define KINO_LEXREADER_BOILERPLATE

typedef void
(*kino_LexReader_destroy_t)(kino_LexReader *self);

typedef struct kino_SegLexicon*
(*kino_LexReader_look_up_term_t)(kino_LexReader *self, 
                            struct kino_Term *target);

typedef struct kino_SegLexicon*
(*kino_LexReader_look_up_field_t)(kino_LexReader *self, 
                             struct kino_ByteBuf *field_name);

typedef struct kino_TermInfo*
(*kino_LexReader_fetch_term_info_t)(kino_LexReader *self, 
                               struct kino_Term *term);

typedef chy_u32_t
(*kino_LexReader_get_skip_interval_t)(kino_LexReader *self);

typedef void
(*kino_LexReader_close_t)(kino_LexReader *self);

#define Kino_LexReader_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_LexReader_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_LexReader_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_LexReader_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_LexReader_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_LexReader_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_LexReader_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_LexReader_Look_Up_Term(self, target) \
    (self)->_->look_up_term((kino_LexReader*)self, target)

#define Kino_LexReader_Look_Up_Field(self, field_name) \
    (self)->_->look_up_field((kino_LexReader*)self, field_name)

#define Kino_LexReader_Fetch_Term_Info(self, term) \
    (self)->_->fetch_term_info((kino_LexReader*)self, term)

#define Kino_LexReader_Get_Skip_Interval(self) \
    (self)->_->get_skip_interval((kino_LexReader*)self)

#define Kino_LexReader_Close(self) \
    (self)->_->close((kino_LexReader*)self)

struct KINO_LEXREADER_VTABLE {
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
    kino_LexReader_look_up_term_t look_up_term;
    kino_LexReader_look_up_field_t look_up_field;
    kino_LexReader_fetch_term_info_t fetch_term_info;
    kino_LexReader_get_skip_interval_t get_skip_interval;
    kino_LexReader_close_t close;
};

extern KINO_LEXREADER_VTABLE KINO_LEXREADER;

#ifdef KINO_USE_SHORT_NAMES
  #define LexReader kino_LexReader
  #define LEXREADER KINO_LEXREADER
  #define LexReader_new kino_LexReader_new
  #define LexReader_destroy kino_LexReader_destroy
  #define LexReader_look_up_term_t kino_LexReader_look_up_term_t
  #define LexReader_look_up_term kino_LexReader_look_up_term
  #define LexReader_look_up_field_t kino_LexReader_look_up_field_t
  #define LexReader_look_up_field kino_LexReader_look_up_field
  #define LexReader_fetch_term_info_t kino_LexReader_fetch_term_info_t
  #define LexReader_fetch_term_info kino_LexReader_fetch_term_info
  #define LexReader_get_skip_interval_t kino_LexReader_get_skip_interval_t
  #define LexReader_get_skip_interval kino_LexReader_get_skip_interval
  #define LexReader_close_t kino_LexReader_close_t
  #define LexReader_close kino_LexReader_close
  #define LexReader_Clone Kino_LexReader_Clone
  #define LexReader_Destroy Kino_LexReader_Destroy
  #define LexReader_Equals Kino_LexReader_Equals
  #define LexReader_Hash_Code Kino_LexReader_Hash_Code
  #define LexReader_Is_A Kino_LexReader_Is_A
  #define LexReader_To_String Kino_LexReader_To_String
  #define LexReader_Serialize Kino_LexReader_Serialize
  #define LexReader_Look_Up_Term Kino_LexReader_Look_Up_Term
  #define LexReader_Look_Up_Field Kino_LexReader_Look_Up_Field
  #define LexReader_Fetch_Term_Info Kino_LexReader_Fetch_Term_Info
  #define LexReader_Get_Skip_Interval Kino_LexReader_Get_Skip_Interval
  #define LexReader_Close Kino_LexReader_Close
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_LEXREADER_MEMBER_VARS \
    chy_u32_t  refcount; \
    struct kino_Schema * schema; \
    struct kino_Folder * folder; \
    struct kino_SegInfo * seg_info; \
    struct kino_SegLexicon ** lexicons; \
    chy_u32_t  num_fields; \
    chy_i32_t  index_interval; \
    chy_i32_t  skip_interval

#ifdef KINO_WANT_LEXREADER_VTABLE
KINO_LEXREADER_VTABLE KINO_LEXREADER = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Index::LexReader",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_LexReader_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_LexReader_look_up_term_t)kino_LexReader_look_up_term,
    (kino_LexReader_look_up_field_t)kino_LexReader_look_up_field,
    (kino_LexReader_fetch_term_info_t)kino_LexReader_fetch_term_info,
    (kino_LexReader_get_skip_interval_t)kino_LexReader_get_skip_interval,
    (kino_LexReader_close_t)kino_LexReader_close
};
#endif /* KINO_WANT_LEXREADER_VTABLE */

#undef KINO_LEXREADER_BOILERPLATE


#endif /* R_KINO_LEXREADER */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
