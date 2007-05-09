/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_MATCHPOSTINGSCORER
#define R_KINO_MATCHPOSTINGSCORER 1

#include "KinoSearch/Posting/MatchPostingScorer.h"

#define KINO_MATCHPOSTINGSCORER_BOILERPLATE



#define Kino_MatchPostScorer_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_MatchPostScorer_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_MatchPostScorer_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_MatchPostScorer_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_MatchPostScorer_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_MatchPostScorer_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_MatchPostScorer_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_MatchPostScorer_Next(self) \
    (self)->_->next((kino_Scorer*)self)

#define Kino_MatchPostScorer_Doc(self) \
    (self)->_->doc((kino_Scorer*)self)

#define Kino_MatchPostScorer_Tally(self) \
    (self)->_->tally((kino_Scorer*)self)

#define Kino_MatchPostScorer_Skip_To(self, target) \
    (self)->_->skip_to((kino_Scorer*)self, target)

#define Kino_MatchPostScorer_Collect(self, hc, start, end, hits_per_seg, seg_starts) \
    (self)->_->collect((kino_Scorer*)self, hc, start, end, hits_per_seg, seg_starts)

struct KINO_MATCHPOSTINGSCORER_VTABLE {
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

extern KINO_MATCHPOSTINGSCORER_VTABLE KINO_MATCHPOSTINGSCORER;

#ifdef KINO_USE_SHORT_NAMES
  #define MatchPostingScorer kino_MatchPostingScorer
  #define MATCHPOSTINGSCORER KINO_MATCHPOSTINGSCORER
  #define MatchPostScorer_new kino_MatchPostScorer_new
  #define MatchPostScorer_Clone Kino_MatchPostScorer_Clone
  #define MatchPostScorer_Destroy Kino_MatchPostScorer_Destroy
  #define MatchPostScorer_Equals Kino_MatchPostScorer_Equals
  #define MatchPostScorer_Hash_Code Kino_MatchPostScorer_Hash_Code
  #define MatchPostScorer_Is_A Kino_MatchPostScorer_Is_A
  #define MatchPostScorer_To_String Kino_MatchPostScorer_To_String
  #define MatchPostScorer_Serialize Kino_MatchPostScorer_Serialize
  #define MatchPostScorer_Next Kino_MatchPostScorer_Next
  #define MatchPostScorer_Doc Kino_MatchPostScorer_Doc
  #define MatchPostScorer_Tally Kino_MatchPostScorer_Tally
  #define MatchPostScorer_Skip_To Kino_MatchPostScorer_Skip_To
  #define MatchPostScorer_Collect Kino_MatchPostScorer_Collect
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_MATCHPOSTINGSCORER_MEMBER_VARS \
    chy_u32_t  refcount; \
    struct kino_Similarity * sim; \
    float  weight_value; \
    float * score_cache; \
    void * weight_ref; \
    struct kino_Tally * tally; \
    struct kino_PostingList * plist; \
    struct kino_ByteBuf * postings; \
    struct kino_Posting * posting

#ifdef KINO_WANT_MATCHPOSTINGSCORER_VTABLE
KINO_MATCHPOSTINGSCORER_VTABLE KINO_MATCHPOSTINGSCORER = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_TERMSCORER,
    "KinoSearch::Posting::MatchPostingScorer",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_TermScorer_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_Scorer_next_t)kino_TermScorer_next,
    (kino_Scorer_doc_t)kino_TermScorer_doc,
    (kino_Scorer_tally_t)kino_TermScorer_tally,
    (kino_Scorer_skip_to_t)kino_TermScorer_skip_to,
    (kino_Scorer_collect_t)kino_Scorer_collect
};
#endif /* KINO_WANT_MATCHPOSTINGSCORER_VTABLE */

#undef KINO_MATCHPOSTINGSCORER_BOILERPLATE


#endif /* R_KINO_MATCHPOSTINGSCORER */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
