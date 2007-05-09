#ifndef H_KINO_SIMILARITY
#define H_KINO_SIMILARITY 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_Similarity kino_Similarity;
typedef struct KINO_SIMILARITY_VTABLE KINO_SIMILARITY_VTABLE;

struct kino_ByteBuf;
struct kino_ViewByteBuf;

KINO_CLASS("KinoSearch::Search::Similarity", "Sim", "KinoSearch::Util::Obj");

struct kino_Similarity {
    KINO_SIMILARITY_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    float         *norm_decoder;
    float         *prox_decoder;
};

/* Constructor.
 */
kino_Similarity* 
kino_Sim_new(const char *class_name);

/* Deserializer.
 */
kino_Similarity*
kino_Sim_deserialize(struct kino_ViewByteBuf *serialized);

/* Return a score factor based on the frequency of a term in a given document.
 * The default implementation is sqrt(freq).  Other implementations typically
 * produce ascending scores with ascending freqs, since the more times a doc
 * matches, the more relevant it is likely to be.
 */
float  
kino_Sim_tf(kino_Similarity *self, float freq);
KINO_METHOD("Kino_Sim_TF");

/* Calculate a score factor based on the number of terms which match. 
 */
float
kino_Sim_coord(kino_Similarity *self, chy_u32_t overlap, 
               chy_u32_t max_overlap);
KINO_METHOD("Kino_Sim_Coord");

/* encode_norm and decode_norm encode and decode between 32-bit IEEE floating
 * point numbers and a 5-bit exponent, 3-bit mantissa float.  The range
 * covered by the single-byte encoding is 7x10^9 to 2x10^-9.  The accuracy is
 * about one significant decimal digit.
 */
chy_u32_t 
kino_Sim_encode_norm(kino_Similarity *self, float f);
KINO_METHOD("Kino_Sim_Encode_Norm");

/* See encode_norm.
 */
float
kino_Sim_decode_norm(kino_Similarity *self, chy_u32_t input);
KINO_METHOD("Kino_Sim_Decode_Norm");

/* Return a boost based which rewards smaller distances between tokens in a
 * search match.
 */
float
kino_Sim_prox_boost(kino_Similarity *self, chy_u32_t distance);
KINO_METHOD("Kino_Sim_Prox_Boost");

/* Assess an array of positions and return a scoring multiplier based on how
 * clustered they are.  The assumption is that documents whose matches are
 * right next to each other deserve higher rank than documents whose matches
 * are spread out and presumably unrelated.
 */
float
kino_Sim_prox_coord(kino_Similarity *self, chy_u32_t *prox, 
                    chy_u32_t num_prox);
KINO_METHOD("Kino_Sim_Prox_Coord");

void
kino_Sim_destroy(kino_Similarity *self);
KINO_METHOD("Kino_Sim_Destroy");

void
kino_Sim_serialize(kino_Similarity *self, struct kino_ByteBuf *target);
KINO_METHOD("Kino_Sim_Serialize");

KINO_END_CLASS

#endif /* H_KINO_SIMILARITY */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

