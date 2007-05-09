/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_SCOREPOSTINGSCORER
#define R_KINO_SCOREPOSTINGSCORER 1

#include "KinoSearch/Posting/ScorePostingScorer.h"

#define KINO_SCOREPOSTINGSCORER_BOILERPLATE

typedef struct kino_Tally*
(*kino_ScorePostScorer_tally_t)(kino_ScorePostingScorer* self);

#define Kino_ScorePostScorer_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_ScorePostScorer_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_ScorePostScorer_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_ScorePostScorer_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_ScorePostScorer_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_ScorePostScorer_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_ScorePostScorer_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_ScorePostScorer_Next(self) \
    (self)->_->next((kino_Scorer*)self)

#define Kino_ScorePostScorer_Doc(self) \
    (self)->_->doc((kino_Scorer*)self)

#define Kino_ScorePostScorer_Tally(self) \
    (self)->_->tally((kino_Scorer*)self)

#define Kino_ScorePostScorer_Skip_To(self, target) \
    (self)->_->skip_to((kino_Scorer*)self, target)

#define Kino_ScorePostScorer_Collect(self, hc, start, end, hits_per_seg, seg_starts) \
    (self)->_->collect((kino_Scorer*)self, hc, start, end, hits_per_seg, seg_starts)

struct KINO_SCOREPOSTINGSCORER_VTABLE {
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
};

extern KINO_SCOREPOSTINGSCORER_VTABLE KINO_SCOREPOSTINGSCORER;

#ifdef KINO_USE_SHORT_NAMES
  #define ScorePostingScorer kino_ScorePostingScorer
  #define SCOREPOSTINGSCORER KINO_SCOREPOSTINGSCORER
  #define ScorePostScorer_new kino_ScorePostScorer_new
  #define ScorePostScorer_tally kino_ScorePostScorer_tally
  #define ScorePostScorer_Clone Kino_ScorePostScorer_Clone
  #define ScorePostScorer_Destroy Kino_ScorePostScorer_Destroy
  #define ScorePostScorer_Equals Kino_ScorePostScorer_Equals
  #define ScorePostScorer_Hash_Code Kino_ScorePostScorer_Hash_Code
  #define ScorePostScorer_Is_A Kino_ScorePostScorer_Is_A
  #define ScorePostScorer_To_String Kino_ScorePostScorer_To_String
  #define ScorePostScorer_Serialize Kino_ScorePostScorer_Serialize
  #define ScorePostScorer_Next Kino_ScorePostScorer_Next
  #define ScorePostScorer_Doc Kino_ScorePostScorer_Doc
  #define ScorePostScorer_Tally Kino_ScorePostScorer_Tally
  #define ScorePostScorer_Skip_To Kino_ScorePostScorer_Skip_To
  #define ScorePostScorer_Collect Kino_ScorePostScorer_Collect
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_SCOREPOSTINGSCORER_MEMBER_VARS \
    chy_u32_t  refcount; \
    struct kino_Similarity * sim; \
    float  weight_value; \
    float * score_cache; \
    void * weight_ref; \
    struct kino_Tally * tally; \
    struct kino_PostingList * plist; \
    struct kino_ByteBuf * postings; \
    struct kino_Posting * posting

#ifdef KINO_WANT_SCOREPOSTINGSCORER_VTABLE
KINO_SCOREPOSTINGSCORER_VTABLE KINO_SCOREPOSTINGSCORER = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_TERMSCORER,
    "KinoSearch::Posting::ScorePostingScorer",
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
    (kino_Scorer_collect_t)kino_Scorer_collect
};
#endif /* KINO_WANT_SCOREPOSTINGSCORER_VTABLE */

#undef KINO_SCOREPOSTINGSCORER_BOILERPLATE


#endif /* R_KINO_SCOREPOSTINGSCORER */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

