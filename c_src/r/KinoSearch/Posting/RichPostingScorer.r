/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_RICHPOSTINGSCORER
#define R_KINO_RICHPOSTINGSCORER 1

#include "KinoSearch/Posting/RichPostingScorer.h"

#define KINO_RICHPOSTINGSCORER_BOILERPLATE



#define Kino_RichPostScorer_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_RichPostScorer_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_RichPostScorer_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_RichPostScorer_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_RichPostScorer_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_RichPostScorer_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_RichPostScorer_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_RichPostScorer_Next(self) \
    (self)->_->next((kino_Scorer*)self)

#define Kino_RichPostScorer_Doc(self) \
    (self)->_->doc((kino_Scorer*)self)

#define Kino_RichPostScorer_Tally(self) \
    (self)->_->tally((kino_Scorer*)self)

#define Kino_RichPostScorer_Skip_To(self, target) \
    (self)->_->skip_to((kino_Scorer*)self, target)

#define Kino_RichPostScorer_Collect(self, hc, start, end, hits_per_seg, seg_starts) \
    (self)->_->collect((kino_Scorer*)self, hc, start, end, hits_per_seg, seg_starts)

#define Kino_RichPostScorer_Max_Matchers(self) \
    (self)->_->max_matchers((kino_Scorer*)self)

struct KINO_RICHPOSTINGSCORER_VTABLE {
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
    kino_Scorer_next_t next;
    kino_Scorer_doc_t doc;
    kino_Scorer_tally_t tally;
    kino_Scorer_skip_to_t skip_to;
    kino_Scorer_collect_t collect;
    kino_Scorer_max_matchers_t max_matchers;
};

extern KINO_RICHPOSTINGSCORER_VTABLE KINO_RICHPOSTINGSCORER;

#ifdef KINO_USE_SHORT_NAMES
  #define RichPostingScorer kino_RichPostingScorer
  #define RICHPOSTINGSCORER KINO_RICHPOSTINGSCORER
  #define RichPostScorer_new kino_RichPostScorer_new
  #define RichPostScorer_Clone Kino_RichPostScorer_Clone
  #define RichPostScorer_Destroy Kino_RichPostScorer_Destroy
  #define RichPostScorer_Equals Kino_RichPostScorer_Equals
  #define RichPostScorer_Hash_Code Kino_RichPostScorer_Hash_Code
  #define RichPostScorer_Is_A Kino_RichPostScorer_Is_A
  #define RichPostScorer_To_String Kino_RichPostScorer_To_String
  #define RichPostScorer_Serialize Kino_RichPostScorer_Serialize
  #define RichPostScorer_Next Kino_RichPostScorer_Next
  #define RichPostScorer_Doc Kino_RichPostScorer_Doc
  #define RichPostScorer_Tally Kino_RichPostScorer_Tally
  #define RichPostScorer_Skip_To Kino_RichPostScorer_Skip_To
  #define RichPostScorer_Collect Kino_RichPostScorer_Collect
  #define RichPostScorer_Max_Matchers Kino_RichPostScorer_Max_Matchers
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_RICHPOSTINGSCORER_MEMBER_VARS \
    chy_u32_t  refcount; \
    struct kino_Similarity * sim; \
    float  weight_value; \
    float * score_cache; \
    struct kino_Native * weight; \
    struct kino_Tally * tally; \
    struct kino_ScoreProx * sprox; \
    struct kino_PostingList * plist; \
    struct kino_Posting * posting

#ifdef KINO_WANT_RICHPOSTINGSCORER_VTABLE
KINO_RICHPOSTINGSCORER_VTABLE KINO_RICHPOSTINGSCORER = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_SCOREPOSTINGSCORER,
    "KinoSearch::Posting::RichPostingScorer",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_TermScorer_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_Scorer_next_t)kino_TermScorer_next,
    (kino_Scorer_doc_t)kino_TermScorer_doc,
    (kino_Scorer_tally_t)kino_ScorePostScorer_tally,
    (kino_Scorer_skip_to_t)kino_TermScorer_skip_to,
    (kino_Scorer_collect_t)kino_Scorer_collect,
    (kino_Scorer_max_matchers_t)kino_Scorer_max_matchers
};
#endif /* KINO_WANT_RICHPOSTINGSCORER_VTABLE */

#undef KINO_RICHPOSTINGSCORER_BOILERPLATE


#endif /* R_KINO_RICHPOSTINGSCORER */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

