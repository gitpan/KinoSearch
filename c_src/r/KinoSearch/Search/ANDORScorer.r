/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_ANDORSCORER
#define R_KINO_ANDORSCORER 1

#include "KinoSearch/Search/ANDORScorer.h"

#define KINO_ANDORSCORER_BOILERPLATE

typedef void
(*kino_ANDORScorer_destroy_t)(kino_ANDORScorer *self);

typedef chy_bool_t
(*kino_ANDORScorer_next_t)(kino_ANDORScorer *self);

typedef chy_u32_t
(*kino_ANDORScorer_doc_t)(kino_ANDORScorer *self);

typedef struct kino_Tally*
(*kino_ANDORScorer_tally_t)(kino_ANDORScorer *self);

typedef chy_bool_t
(*kino_ANDORScorer_skip_to_t)(kino_ANDORScorer *self, chy_u32_t target);

typedef chy_u32_t
(*kino_ANDORScorer_max_matchers_t)(kino_ANDORScorer *self);

#define Kino_ANDORScorer_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_ANDORScorer_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_ANDORScorer_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_ANDORScorer_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_ANDORScorer_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_ANDORScorer_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_ANDORScorer_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_ANDORScorer_Next(self) \
    (self)->_->next((kino_Scorer*)self)

#define Kino_ANDORScorer_Doc(self) \
    (self)->_->doc((kino_Scorer*)self)

#define Kino_ANDORScorer_Tally(self) \
    (self)->_->tally((kino_Scorer*)self)

#define Kino_ANDORScorer_Skip_To(self, target) \
    (self)->_->skip_to((kino_Scorer*)self, target)

#define Kino_ANDORScorer_Collect(self, hc, start, end, hits_per_seg, seg_starts) \
    (self)->_->collect((kino_Scorer*)self, hc, start, end, hits_per_seg, seg_starts)

#define Kino_ANDORScorer_Max_Matchers(self) \
    (self)->_->max_matchers((kino_Scorer*)self)

struct KINO_ANDORSCORER_VTABLE {
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

extern KINO_ANDORSCORER_VTABLE KINO_ANDORSCORER;

#ifdef KINO_USE_SHORT_NAMES
  #define ANDORScorer kino_ANDORScorer
  #define ANDORSCORER KINO_ANDORSCORER
  #define ANDORScorer_new kino_ANDORScorer_new
  #define ANDORScorer_destroy kino_ANDORScorer_destroy
  #define ANDORScorer_next kino_ANDORScorer_next
  #define ANDORScorer_doc kino_ANDORScorer_doc
  #define ANDORScorer_tally kino_ANDORScorer_tally
  #define ANDORScorer_skip_to kino_ANDORScorer_skip_to
  #define ANDORScorer_max_matchers kino_ANDORScorer_max_matchers
  #define ANDORScorer_Clone Kino_ANDORScorer_Clone
  #define ANDORScorer_Destroy Kino_ANDORScorer_Destroy
  #define ANDORScorer_Equals Kino_ANDORScorer_Equals
  #define ANDORScorer_Hash_Code Kino_ANDORScorer_Hash_Code
  #define ANDORScorer_Is_A Kino_ANDORScorer_Is_A
  #define ANDORScorer_To_String Kino_ANDORScorer_To_String
  #define ANDORScorer_Serialize Kino_ANDORScorer_Serialize
  #define ANDORScorer_Next Kino_ANDORScorer_Next
  #define ANDORScorer_Doc Kino_ANDORScorer_Doc
  #define ANDORScorer_Tally Kino_ANDORScorer_Tally
  #define ANDORScorer_Skip_To Kino_ANDORScorer_Skip_To
  #define ANDORScorer_Collect Kino_ANDORScorer_Collect
  #define ANDORScorer_Max_Matchers Kino_ANDORScorer_Max_Matchers
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_ANDORSCORER_MEMBER_VARS \
    chy_u32_t  refcount; \
    struct kino_Similarity * sim; \
    struct kino_Tally * tally; \
    kino_Scorer * and_scorer; \
    kino_Scorer * or_scorer; \
    chy_bool_t  or_scorer_first_time

#ifdef KINO_WANT_ANDORSCORER_VTABLE
KINO_ANDORSCORER_VTABLE KINO_ANDORSCORER = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_SCORER,
    "KinoSearch::Search::ANDORScorer",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_ANDORScorer_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_Scorer_next_t)kino_ANDORScorer_next,
    (kino_Scorer_doc_t)kino_ANDORScorer_doc,
    (kino_Scorer_tally_t)kino_ANDORScorer_tally,
    (kino_Scorer_skip_to_t)kino_ANDORScorer_skip_to,
    (kino_Scorer_collect_t)kino_Scorer_collect,
    (kino_Scorer_max_matchers_t)kino_ANDORScorer_max_matchers
};
#endif /* KINO_WANT_ANDORSCORER_VTABLE */

#undef KINO_ANDORSCORER_BOILERPLATE


#endif /* R_KINO_ANDORSCORER */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

