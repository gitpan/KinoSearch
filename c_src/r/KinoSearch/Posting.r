/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_POSTING
#define R_KINO_POSTING 1

#include "KinoSearch/Posting.h"

#define KINO_POSTING_BOILERPLATE

typedef void
(*kino_Post_destroy_t)(kino_Posting *self);

typedef chy_u32_t
(*kino_Post_bulk_read_t)(kino_Posting *self, struct kino_InStream *instream, 
                    struct kino_ByteBuf *postings, chy_u32_t num_wanted);

typedef struct kino_RawPosting*
(*kino_Post_read_raw_t)(kino_Posting *self, struct kino_InStream *instream,
                   chy_u32_t last_doc_num, struct kino_ByteBuf *term_text, 
                   struct kino_MemoryPool *mem_pool);

typedef void
(*kino_Post_add_batch_to_pool_t)(kino_Posting *self, 
                            struct kino_PostingPool *post_pool, 
                            struct kino_TokenBatch *batch, 
                            struct kino_FieldSpec *fspec, 
                            chy_u32_t doc_num, float doc_boost, 
                            float length_norm);

typedef void
(*kino_Post_reset_t)(kino_Posting *self, chy_u32_t doc_num);

typedef struct kino_Scorer*
(*kino_Post_make_scorer_t)(kino_Posting *self, struct kino_Similarity *sim,
                      struct kino_PostingList *plist,
                      void *weight, float weight_val);

typedef kino_Posting*
(*kino_Post_dupe_t)(kino_Posting *self, struct kino_Similarity *sim);

#define Kino_Post_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_Post_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_Post_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_Post_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_Post_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_Post_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_Post_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_Post_Read_Record(self, instream) \
    (self)->_->read_record((kino_Stepper*)self, instream)

#define Kino_Post_Dump(self, instream) \
    (self)->_->dump((kino_Stepper*)self, instream)

#define Kino_Post_Dump_To_File(self, instream, outstream) \
    (self)->_->dump_to_file((kino_Stepper*)self, instream, outstream)

#define Kino_Post_Bulk_Read(self, instream, postings, num_wanted) \
    (self)->_->bulk_read((kino_Posting*)self, instream, postings, num_wanted)

#define Kino_Post_Read_Raw(self, instream, last_doc_num, term_text, mem_pool) \
    (self)->_->read_raw((kino_Posting*)self, instream, last_doc_num, term_text, mem_pool)

#define Kino_Post_Add_Batch_To_Pool(self, post_pool, batch, fspec, doc_num, doc_boost, length_norm) \
    (self)->_->add_batch_to_pool((kino_Posting*)self, post_pool, batch, fspec, doc_num, doc_boost, length_norm)

#define Kino_Post_Reset(self, doc_num) \
    (self)->_->reset((kino_Posting*)self, doc_num)

#define Kino_Post_Make_Scorer(self, sim, plist, weight, weight_val) \
    (self)->_->make_scorer((kino_Posting*)self, sim, plist, weight, weight_val)

#define Kino_Post_Dupe(self, sim) \
    (self)->_->dupe((kino_Posting*)self, sim)

struct KINO_POSTING_VTABLE {
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
    kino_Stepper_read_record_t read_record;
    kino_Stepper_dump_t dump;
    kino_Stepper_dump_to_file_t dump_to_file;
    kino_Post_bulk_read_t bulk_read;
    kino_Post_read_raw_t read_raw;
    kino_Post_add_batch_to_pool_t add_batch_to_pool;
    kino_Post_reset_t reset;
    kino_Post_make_scorer_t make_scorer;
    kino_Post_dupe_t dupe;
};

extern KINO_POSTING_VTABLE KINO_POSTING;

#ifdef KINO_USE_SHORT_NAMES
  #define Posting kino_Posting
  #define POSTING KINO_POSTING
  #define Post_destroy kino_Post_destroy
  #define Post_bulk_read_t kino_Post_bulk_read_t
  #define Post_bulk_read kino_Post_bulk_read
  #define Post_read_raw_t kino_Post_read_raw_t
  #define Post_read_raw kino_Post_read_raw
  #define Post_add_batch_to_pool_t kino_Post_add_batch_to_pool_t
  #define Post_add_batch_to_pool kino_Post_add_batch_to_pool
  #define Post_reset_t kino_Post_reset_t
  #define Post_reset kino_Post_reset
  #define Post_make_scorer_t kino_Post_make_scorer_t
  #define Post_make_scorer kino_Post_make_scorer
  #define Post_dupe_t kino_Post_dupe_t
  #define Post_dupe kino_Post_dupe
  #define Post_Clone Kino_Post_Clone
  #define Post_Destroy Kino_Post_Destroy
  #define Post_Equals Kino_Post_Equals
  #define Post_Hash_Code Kino_Post_Hash_Code
  #define Post_Is_A Kino_Post_Is_A
  #define Post_To_String Kino_Post_To_String
  #define Post_Serialize Kino_Post_Serialize
  #define Post_Read_Record Kino_Post_Read_Record
  #define Post_Dump Kino_Post_Dump
  #define Post_Dump_To_File Kino_Post_Dump_To_File
  #define Post_Bulk_Read Kino_Post_Bulk_Read
  #define Post_Read_Raw Kino_Post_Read_Raw
  #define Post_Add_Batch_To_Pool Kino_Post_Add_Batch_To_Pool
  #define Post_Reset Kino_Post_Reset
  #define Post_Make_Scorer Kino_Post_Make_Scorer
  #define Post_Dupe Kino_Post_Dupe
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_POSTING_MEMBER_VARS \
    chy_u32_t  refcount; \
    struct kino_Similarity * sim; \
    kino_Posting * next; \
    chy_u32_t  doc_num

#ifdef KINO_WANT_POSTING_VTABLE
KINO_POSTING_VTABLE KINO_POSTING = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_STEPPER,
    "KinoSearch::Posting",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Post_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_Stepper_read_record_t)kino_Stepper_read_record,
    (kino_Stepper_dump_t)kino_Stepper_dump,
    (kino_Stepper_dump_to_file_t)kino_Stepper_dump_to_file,
    (kino_Post_bulk_read_t)kino_Post_bulk_read,
    (kino_Post_read_raw_t)kino_Post_read_raw,
    (kino_Post_add_batch_to_pool_t)kino_Post_add_batch_to_pool,
    (kino_Post_reset_t)kino_Post_reset,
    (kino_Post_make_scorer_t)kino_Post_make_scorer,
    (kino_Post_dupe_t)kino_Post_dupe
};
#endif /* KINO_WANT_POSTING_VTABLE */

#undef KINO_POSTING_BOILERPLATE


#endif /* R_KINO_POSTING */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
