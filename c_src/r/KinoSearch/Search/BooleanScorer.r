/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_BOOLEANSCORER
#define R_KINO_BOOLEANSCORER 1

#include "KinoSearch/Search/BooleanScorer.h"

#define KINO_BOOLEANSCORER_BOILERPLATE

typedef void
(*kino_BoolScorer_destroy_t)(kino_BooleanScorer *self);

typedef chy_bool_t
(*kino_BoolScorer_next_t)(kino_BooleanScorer *self);

typedef chy_u32_t
(*kino_BoolScorer_doc_t)(kino_BooleanScorer *self);

typedef struct kino_Tally*
(*kino_BoolScorer_tally_t)(kino_BooleanScorer *self);

typedef chy_bool_t
(*kino_BoolScorer_skip_to_t)(kino_BooleanScorer *self, chy_u32_t target);

typedef void
(*kino_BoolScorer_add_subscorer_t)(kino_BooleanScorer* self, 
                              kino_Scorer* subscorer, 
                              const struct kino_ByteBuf *occur);

#define Kino_BoolScorer_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_BoolScorer_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_BoolScorer_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_BoolScorer_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_BoolScorer_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_BoolScorer_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_BoolScorer_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_BoolScorer_Next(self) \
    (self)->_->next((kino_Scorer*)self)

#define Kino_BoolScorer_Doc(self) \
    (self)->_->doc((kino_Scorer*)self)

#define Kino_BoolScorer_Tally(self) \
    (self)->_->tally((kino_Scorer*)self)

#define Kino_BoolScorer_Skip_To(self, target) \
    (self)->_->skip_to((kino_Scorer*)self, target)

#define Kino_BoolScorer_Collect(self, hc, start, end, hits_per_seg, seg_starts) \
    (self)->_->collect((kino_Scorer*)self, hc, start, end, hits_per_seg, seg_starts)

#define Kino_BoolScorer_Add_Subscorer(self, subscorer, occur) \
    (self)->_->add_subscorer((kino_BooleanScorer*)self, subscorer, occur)

struct KINO_BOOLEANSCORER_VTABLE {
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
    kino_BoolScorer_add_subscorer_t add_subscorer;
};

extern KINO_BOOLEANSCORER_VTABLE KINO_BOOLEANSCORER;

#ifdef KINO_USE_SHORT_NAMES
  #define BooleanScorer kino_BooleanScorer
  #define BOOLEANSCORER KINO_BOOLEANSCORER
  #define BoolScorer_new kino_BoolScorer_new
  #define BoolScorer_destroy kino_BoolScorer_destroy
  #define BoolScorer_next kino_BoolScorer_next
  #define BoolScorer_doc kino_BoolScorer_doc
  #define BoolScorer_tally kino_BoolScorer_tally
  #define BoolScorer_skip_to kino_BoolScorer_skip_to
  #define BoolScorer_add_subscorer_t kino_BoolScorer_add_subscorer_t
  #define BoolScorer_add_subscorer kino_BoolScorer_add_subscorer
  #define BoolScorer_Clone Kino_BoolScorer_Clone
  #define BoolScorer_Destroy Kino_BoolScorer_Destroy
  #define BoolScorer_Equals Kino_BoolScorer_Equals
  #define BoolScorer_Hash_Code Kino_BoolScorer_Hash_Code
  #define BoolScorer_Is_A Kino_BoolScorer_Is_A
  #define BoolScorer_To_String Kino_BoolScorer_To_String
  #define BoolScorer_Serialize Kino_BoolScorer_Serialize
  #define BoolScorer_Next Kino_BoolScorer_Next
  #define BoolScorer_Doc Kino_BoolScorer_Doc
  #define BoolScorer_Tally Kino_BoolScorer_Tally
  #define BoolScorer_Skip_To Kino_BoolScorer_Skip_To
  #define BoolScorer_Collect Kino_BoolScorer_Collect
  #define BoolScorer_Add_Subscorer Kino_BoolScorer_Add_Subscorer
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_BOOLEANSCORER_MEMBER_VARS \
    chy_u32_t  refcount; \
    struct kino_Similarity * sim; \
    struct kino_Scorer * scorer; \
    struct kino_Tally * tally; \
    struct kino_VArray * and_scorers; \
    struct kino_VArray * or_scorers; \
    struct kino_VArray * not_scorers; \
    chy_u32_t  max_coord; \
    float * coord_factors; \
    kino_Scorer_next_t  do_next; \
    kino_Scorer_skip_to_t  do_skip_to; \
    chy_bool_t  first_time

#ifdef KINO_WANT_BOOLEANSCORER_VTABLE
KINO_BOOLEANSCORER_VTABLE KINO_BOOLEANSCORER = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_SCORER,
    "KinoSearch::Search::BooleanScorer",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_BoolScorer_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_Scorer_next_t)kino_BoolScorer_next,
    (kino_Scorer_doc_t)kino_BoolScorer_doc,
    (kino_Scorer_tally_t)kino_BoolScorer_tally,
    (kino_Scorer_skip_to_t)kino_BoolScorer_skip_to,
    (kino_Scorer_collect_t)kino_Scorer_collect,
    (kino_BoolScorer_add_subscorer_t)kino_BoolScorer_add_subscorer
};
#endif /* KINO_WANT_BOOLEANSCORER_VTABLE */

#undef KINO_BOOLEANSCORER_BOILERPLATE


#endif /* R_KINO_BOOLEANSCORER */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

