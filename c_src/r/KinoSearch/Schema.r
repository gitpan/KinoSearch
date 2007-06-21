/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_SCHEMA
#define R_KINO_SCHEMA 1

#include "KinoSearch/Schema.h"

#define KINO_SCHEMA_BOILERPLATE

typedef void
(*kino_Schema_destroy_t)(kino_Schema *self);

typedef void
(*kino_Schema_add_field_t)(kino_Schema *self, 
                      const struct kino_ByteBuf *field_name,
                      struct kino_FieldSpec *field_spec);

typedef struct kino_FieldSpec*
(*kino_Schema_fetch_fspec_t)(kino_Schema *self, 
                        const struct kino_ByteBuf *field_name);

typedef struct kino_Similarity*
(*kino_Schema_fetch_sim_t)(kino_Schema *self, 
                      const struct kino_ByteBuf *field_name);

typedef struct kino_Posting*
(*kino_Schema_fetch_posting_t)(kino_Schema *self, 
                          const struct kino_ByteBuf *field_name);

typedef chy_u32_t
(*kino_Schema_num_fields_t)(kino_Schema *self);

typedef chy_i32_t
(*kino_Schema_field_num_t)(kino_Schema *self, 
                      const struct kino_ByteBuf *field_name);

typedef struct kino_VArray*
(*kino_Schema_all_fields_t)(kino_Schema *self);

#define Kino_Schema_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_Schema_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_Schema_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_Schema_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_Schema_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_Schema_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_Schema_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_Schema_Add_Field(self, field_name, field_spec) \
    (self)->_->add_field((kino_Schema*)self, field_name, field_spec)

#define Kino_Schema_Fetch_FSpec(self, field_name) \
    (self)->_->fetch_fspec((kino_Schema*)self, field_name)

#define Kino_Schema_Fetch_Sim(self, field_name) \
    (self)->_->fetch_sim((kino_Schema*)self, field_name)

#define Kino_Schema_Fetch_Posting(self, field_name) \
    (self)->_->fetch_posting((kino_Schema*)self, field_name)

#define Kino_Schema_Num_Fields(self) \
    (self)->_->num_fields((kino_Schema*)self)

#define Kino_Schema_Field_Num(self, field_name) \
    (self)->_->field_num((kino_Schema*)self, field_name)

#define Kino_Schema_All_Fields(self) \
    (self)->_->all_fields((kino_Schema*)self)

struct KINO_SCHEMA_VTABLE {
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
    kino_Schema_add_field_t add_field;
    kino_Schema_fetch_fspec_t fetch_fspec;
    kino_Schema_fetch_sim_t fetch_sim;
    kino_Schema_fetch_posting_t fetch_posting;
    kino_Schema_num_fields_t num_fields;
    kino_Schema_field_num_t field_num;
    kino_Schema_all_fields_t all_fields;
};

extern KINO_SCHEMA_VTABLE KINO_SCHEMA;

#ifdef KINO_USE_SHORT_NAMES
  #define Schema kino_Schema
  #define SCHEMA KINO_SCHEMA
  #define Schema_new kino_Schema_new
  #define Schema_destroy kino_Schema_destroy
  #define Schema_add_field_t kino_Schema_add_field_t
  #define Schema_add_field kino_Schema_add_field
  #define Schema_fetch_fspec_t kino_Schema_fetch_fspec_t
  #define Schema_fetch_fspec kino_Schema_fetch_fspec
  #define Schema_fetch_sim_t kino_Schema_fetch_sim_t
  #define Schema_fetch_sim kino_Schema_fetch_sim
  #define Schema_fetch_posting_t kino_Schema_fetch_posting_t
  #define Schema_fetch_posting kino_Schema_fetch_posting
  #define Schema_num_fields_t kino_Schema_num_fields_t
  #define Schema_num_fields kino_Schema_num_fields
  #define Schema_field_num_t kino_Schema_field_num_t
  #define Schema_field_num kino_Schema_field_num
  #define Schema_all_fields_t kino_Schema_all_fields_t
  #define Schema_all_fields kino_Schema_all_fields
  #define Schema_Clone Kino_Schema_Clone
  #define Schema_Destroy Kino_Schema_Destroy
  #define Schema_Equals Kino_Schema_Equals
  #define Schema_Hash_Code Kino_Schema_Hash_Code
  #define Schema_Is_A Kino_Schema_Is_A
  #define Schema_To_String Kino_Schema_To_String
  #define Schema_Serialize Kino_Schema_Serialize
  #define Schema_Add_Field Kino_Schema_Add_Field
  #define Schema_Fetch_FSpec Kino_Schema_Fetch_FSpec
  #define Schema_Fetch_Sim Kino_Schema_Fetch_Sim
  #define Schema_Fetch_Posting Kino_Schema_Fetch_Posting
  #define Schema_Num_Fields Kino_Schema_Num_Fields
  #define Schema_Field_Num Kino_Schema_Field_Num
  #define Schema_All_Fields Kino_Schema_All_Fields
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_SCHEMA_MEMBER_VARS \
    chy_u32_t  refcount; \
    struct kino_Similarity * sim; \
    struct kino_Hash * fspecs; \
    struct kino_Hash * by_name; \
    struct kino_VArray * by_num; \
    struct kino_Hash * sims; \
    struct kino_Hash * postings; \
    struct kino_Native * analyzers; \
    struct kino_Native * analyzer; \
    chy_i32_t  index_interval; \
    chy_i32_t  skip_interval

#ifdef KINO_WANT_SCHEMA_VTABLE
KINO_SCHEMA_VTABLE KINO_SCHEMA = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Schema",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Schema_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_Schema_add_field_t)kino_Schema_add_field,
    (kino_Schema_fetch_fspec_t)kino_Schema_fetch_fspec,
    (kino_Schema_fetch_sim_t)kino_Schema_fetch_sim,
    (kino_Schema_fetch_posting_t)kino_Schema_fetch_posting,
    (kino_Schema_num_fields_t)kino_Schema_num_fields,
    (kino_Schema_field_num_t)kino_Schema_field_num,
    (kino_Schema_all_fields_t)kino_Schema_all_fields
};
#endif /* KINO_WANT_SCHEMA_VTABLE */

#undef KINO_SCHEMA_BOILERPLATE


#endif /* R_KINO_SCHEMA */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

