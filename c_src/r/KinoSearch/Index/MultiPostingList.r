/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_MULTIPOSTINGLIST
#define R_KINO_MULTIPOSTINGLIST 1

#include "KinoSearch/Index/MultiPostingList.h"

#define KINO_MULTIPOSTINGLIST_BOILERPLATE

typedef void
(*kino_MultiPList_destroy_t)(kino_MultiPostingList *self);

typedef struct kino_Posting*
(*kino_MultiPList_get_posting_t)(kino_MultiPostingList *self);

typedef chy_u32_t
(*kino_MultiPList_get_doc_freq_t)(kino_MultiPostingList *self);

typedef chy_u32_t
(*kino_MultiPList_get_doc_num_t)(kino_MultiPostingList *self);

typedef void
(*kino_MultiPList_seek_t)(kino_MultiPostingList *self, struct kino_Term *target);

typedef chy_bool_t
(*kino_MultiPList_next_t)(kino_MultiPostingList *self);

typedef chy_bool_t
(*kino_MultiPList_skip_to_t)(kino_MultiPostingList *self, chy_u32_t target);

typedef chy_u32_t
(*kino_MultiPList_bulk_read_t)(kino_MultiPostingList *self, 
                          struct kino_ByteBuf *postings, 
                          chy_u32_t num_wanted);

typedef struct kino_Scorer*
(*kino_MultiPList_make_scorer_t)(kino_MultiPostingList *self, 
                            struct kino_Similarity *sim,
                            void *weight, float weight_val);

#define Kino_MultiPList_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_MultiPList_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_MultiPList_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_MultiPList_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_MultiPList_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_MultiPList_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_MultiPList_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_MultiPList_Get_Posting(self) \
    (self)->_->get_posting((kino_PostingList*)self)

#define Kino_MultiPList_Get_Doc_Freq(self) \
    (self)->_->get_doc_freq((kino_PostingList*)self)

#define Kino_MultiPList_Get_Doc_Num(self) \
    (self)->_->get_doc_num((kino_PostingList*)self)

#define Kino_MultiPList_Seek(self, target) \
    (self)->_->seek((kino_PostingList*)self, target)

#define Kino_MultiPList_Seek_Lex(self, lexicon) \
    (self)->_->seek_lex((kino_PostingList*)self, lexicon)

#define Kino_MultiPList_Next(self) \
    (self)->_->next((kino_PostingList*)self)

#define Kino_MultiPList_Skip_To(self, target) \
    (self)->_->skip_to((kino_PostingList*)self, target)

#define Kino_MultiPList_Bulk_Read(self, postings, num_wanted) \
    (self)->_->bulk_read((kino_PostingList*)self, postings, num_wanted)

#define Kino_MultiPList_Make_Scorer(self, sim, weight, weight_val) \
    (self)->_->make_scorer((kino_PostingList*)self, sim, weight, weight_val)

struct KINO_MULTIPOSTINGLIST_VTABLE {
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
    kino_PList_get_posting_t get_posting;
    kino_PList_get_doc_freq_t get_doc_freq;
    kino_PList_get_doc_num_t get_doc_num;
    kino_PList_seek_t seek;
    kino_PList_seek_lex_t seek_lex;
    kino_PList_next_t next;
    kino_PList_skip_to_t skip_to;
    kino_PList_bulk_read_t bulk_read;
    kino_PList_make_scorer_t make_scorer;
};

extern KINO_MULTIPOSTINGLIST_VTABLE KINO_MULTIPOSTINGLIST;

#ifdef KINO_USE_SHORT_NAMES
  #define MultiPostingList kino_MultiPostingList
  #define MULTIPOSTINGLIST KINO_MULTIPOSTINGLIST
  #define MultiPList_new kino_MultiPList_new
  #define MultiPList_destroy kino_MultiPList_destroy
  #define MultiPList_get_posting kino_MultiPList_get_posting
  #define MultiPList_get_doc_freq kino_MultiPList_get_doc_freq
  #define MultiPList_get_doc_num kino_MultiPList_get_doc_num
  #define MultiPList_seek kino_MultiPList_seek
  #define MultiPList_next kino_MultiPList_next
  #define MultiPList_skip_to kino_MultiPList_skip_to
  #define MultiPList_bulk_read kino_MultiPList_bulk_read
  #define MultiPList_make_scorer kino_MultiPList_make_scorer
  #define MultiPList_Clone Kino_MultiPList_Clone
  #define MultiPList_Destroy Kino_MultiPList_Destroy
  #define MultiPList_Equals Kino_MultiPList_Equals
  #define MultiPList_Hash_Code Kino_MultiPList_Hash_Code
  #define MultiPList_Is_A Kino_MultiPList_Is_A
  #define MultiPList_To_String Kino_MultiPList_To_String
  #define MultiPList_Serialize Kino_MultiPList_Serialize
  #define MultiPList_Get_Posting Kino_MultiPList_Get_Posting
  #define MultiPList_Get_Doc_Freq Kino_MultiPList_Get_Doc_Freq
  #define MultiPList_Get_Doc_Num Kino_MultiPList_Get_Doc_Num
  #define MultiPList_Seek Kino_MultiPList_Seek
  #define MultiPList_Seek_Lex Kino_MultiPList_Seek_Lex
  #define MultiPList_Next Kino_MultiPList_Next
  #define MultiPList_Skip_To Kino_MultiPList_Skip_To
  #define MultiPList_Bulk_Read Kino_MultiPList_Bulk_Read
  #define MultiPList_Make_Scorer Kino_MultiPList_Make_Scorer
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_MULTIPOSTINGLIST_MEMBER_VARS \
    chy_u32_t  refcount; \
    struct kino_ByteBuf * field; \
    struct kino_VArray * sub_plists; \
    struct kino_SegPostingList * current; \
    chy_u32_t  num_subs; \
    chy_u32_t  tick

#ifdef KINO_WANT_MULTIPOSTINGLIST_VTABLE
KINO_MULTIPOSTINGLIST_VTABLE KINO_MULTIPOSTINGLIST = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_POSTINGLIST,
    "KinoSearch::Index::MultiPostingList",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_MultiPList_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_PList_get_posting_t)kino_MultiPList_get_posting,
    (kino_PList_get_doc_freq_t)kino_MultiPList_get_doc_freq,
    (kino_PList_get_doc_num_t)kino_MultiPList_get_doc_num,
    (kino_PList_seek_t)kino_MultiPList_seek,
    (kino_PList_seek_lex_t)kino_PList_seek_lex,
    (kino_PList_next_t)kino_MultiPList_next,
    (kino_PList_skip_to_t)kino_MultiPList_skip_to,
    (kino_PList_bulk_read_t)kino_MultiPList_bulk_read,
    (kino_PList_make_scorer_t)kino_MultiPList_make_scorer
};
#endif /* KINO_WANT_MULTIPOSTINGLIST_VTABLE */

#undef KINO_MULTIPOSTINGLIST_BOILERPLATE


#endif /* R_KINO_MULTIPOSTINGLIST */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
