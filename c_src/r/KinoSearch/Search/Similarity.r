/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_SIM
#define R_KINO_SIM 1

#include "KinoSearch/Search/Similarity.h"

typedef void
(*kino_Sim_destroy_t)(kino_Similarity *self);

typedef void
(*kino_Sim_serialize_t)(kino_Similarity *self, struct kino_ByteBuf *target);

typedef float
(*kino_Sim_tf_t)(kino_Similarity *self, float freq);

typedef float
(*kino_Sim_coord_t)(kino_Similarity *self, kino_u32_t overlap, 
               kino_u32_t max_overlap);

typedef kino_u32_t
(*kino_Sim_encode_norm_t)(kino_Similarity *self, float f);

typedef float
(*kino_Sim_decode_norm_t)(kino_Similarity *self, kino_u32_t input);

typedef float
(*kino_Sim_prox_boost_t)(kino_Similarity *self, kino_u32_t distance);

typedef float
(*kino_Sim_prox_coord_t)(kino_Similarity *self, kino_u32_t *prox, 
                    kino_u32_t num_prox);

#define Kino_Sim_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_Sim_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_Sim_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_Sim_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_Sim_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_Sim_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_Sim_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_Sim_TF(_self, _arg1) \
    (_self)->_->tf((kino_Similarity*)_self, _arg1)

#define Kino_Sim_Coord(_self, _arg1, _arg2) \
    (_self)->_->coord((kino_Similarity*)_self, _arg1, _arg2)

#define Kino_Sim_Encode_Norm(_self, _arg1) \
    (_self)->_->encode_norm((kino_Similarity*)_self, _arg1)

#define Kino_Sim_Decode_Norm(_self, _arg1) \
    (_self)->_->decode_norm((kino_Similarity*)_self, _arg1)

#define Kino_Sim_Prox_Boost(_self, _arg1) \
    (_self)->_->prox_boost((kino_Similarity*)_self, _arg1)

#define Kino_Sim_Prox_Coord(_self, _arg1, _arg2) \
    (_self)->_->prox_coord((kino_Similarity*)_self, _arg1, _arg2)

struct KINO_SIMILARITY_VTABLE {
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
    kino_Sim_tf_t tf;
    kino_Sim_coord_t coord;
    kino_Sim_encode_norm_t encode_norm;
    kino_Sim_decode_norm_t decode_norm;
    kino_Sim_prox_boost_t prox_boost;
    kino_Sim_prox_coord_t prox_coord;
};

extern KINO_SIMILARITY_VTABLE KINO_SIMILARITY;

#ifdef KINO_USE_SHORT_NAMES
  #define Similarity kino_Similarity
  #define SIMILARITY KINO_SIMILARITY
  #define Sim_new kino_Sim_new
  #define Sim_deserialize kino_Sim_deserialize
  #define Sim_destroy kino_Sim_destroy
  #define Sim_serialize kino_Sim_serialize
  #define Sim_tf_t kino_Sim_tf_t
  #define Sim_tf kino_Sim_tf
  #define Sim_coord_t kino_Sim_coord_t
  #define Sim_coord kino_Sim_coord
  #define Sim_encode_norm_t kino_Sim_encode_norm_t
  #define Sim_encode_norm kino_Sim_encode_norm
  #define Sim_decode_norm_t kino_Sim_decode_norm_t
  #define Sim_decode_norm kino_Sim_decode_norm
  #define Sim_prox_boost_t kino_Sim_prox_boost_t
  #define Sim_prox_boost kino_Sim_prox_boost
  #define Sim_prox_coord_t kino_Sim_prox_coord_t
  #define Sim_prox_coord kino_Sim_prox_coord
  #define Sim_Clone Kino_Sim_Clone
  #define Sim_Destroy Kino_Sim_Destroy
  #define Sim_Equals Kino_Sim_Equals
  #define Sim_Hash_Code Kino_Sim_Hash_Code
  #define Sim_Is_A Kino_Sim_Is_A
  #define Sim_To_String Kino_Sim_To_String
  #define Sim_Serialize Kino_Sim_Serialize
  #define Sim_TF Kino_Sim_TF
  #define Sim_Coord Kino_Sim_Coord
  #define Sim_Encode_Norm Kino_Sim_Encode_Norm
  #define Sim_Decode_Norm Kino_Sim_Decode_Norm
  #define Sim_Prox_Boost Kino_Sim_Prox_Boost
  #define Sim_Prox_Coord Kino_Sim_Prox_Coord
  #define SIMILARITY KINO_SIMILARITY
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_SIMILARITY_MEMBER_VARS \
    float * norm_decoder; \
    float * prox_decoder;


#ifdef KINO_WANT_SIMILARITY_VTABLE
KINO_SIMILARITY_VTABLE KINO_SIMILARITY = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Search::Similarity",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_Sim_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Sim_serialize,
    (kino_Sim_tf_t)kino_Sim_tf,
    (kino_Sim_coord_t)kino_Sim_coord,
    (kino_Sim_encode_norm_t)kino_Sim_encode_norm,
    (kino_Sim_decode_norm_t)kino_Sim_decode_norm,
    (kino_Sim_prox_boost_t)kino_Sim_prox_boost,
    (kino_Sim_prox_coord_t)kino_Sim_prox_coord
};
#endif /* KINO_WANT_SIMILARITY_VTABLE */

#endif /* R_KINO_SIM */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
