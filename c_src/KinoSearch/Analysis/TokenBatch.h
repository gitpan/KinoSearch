/** 
 * @class KinoSearch::Analysis::TokenBatch Tokenbatch.r
 * @brief A collection of Tokens.
 *
 * A TokenBatch is a collection of Token objects which you can add to, then
 * iterate over. 
 */

#ifndef H_KINO_TOKENBATCH
#define H_KINO_TOKENBATCH 1

#include "KinoSearch/Util/VArray.r"

struct kino_Token;
struct kino_ByteBuf;

typedef struct kino_TokenBatch kino_TokenBatch;
typedef struct KINO_TOKENBATCH_VTABLE KINO_TOKENBATCH_VTABLE;

KINO_CLASS("KinoSearch::Analysis::TokenBatch", "TokenBatch", 
    "KinoSearch::Util::VArray");

/** 
 * @struct kino_TokenBatch 
 */
struct kino_TokenBatch {
    KINO_TOKENBATCH_VTABLE *_;         
    KINO_VARRAY_MEMBER_VARS;          
    kino_u32_t cur;                    /**< pointer to current token */
    kino_bool_t inverted;              /**< batch has been inverted */
    kino_u32_t *cluster_counts;        /**< counts per unique text */
    kino_u32_t  cluster_counts_size;   /**< num unique texts */
};

/** Constructor.
 * 
 * @param seed_token An initial Token to start things off, which may be NULL.
 */
KINO_FUNCTION(
kino_TokenBatch* 
kino_TokenBatch_new(struct kino_Token *seed_token));

/** @def TokenBatch_Append(self, token)
 * 
 * Tack a token onto the end of the batch
 *
 * @param token A Token.
 */
KINO_METHOD("Kino_TokenBatch_Append",
void
kino_TokenBatch_append(kino_TokenBatch *self, struct kino_Token *token));

/** @def TokenBatch_Next(self)
 * 
 * Return the next token in the TokenBatch until out of tokens.
 */
KINO_METHOD("Kino_TokenBatch_Next",
struct kino_Token*
kino_TokenBatch_next(kino_TokenBatch *self));

/** @def TokenBatch_Reset(self)
 *
 * Reset the TokenBatch's iterator, so that the next call to next() returns the
 * first Token in the batch.
 */
KINO_METHOD("Kino_TokenBatch_Reset",
void
kino_TokenBatch_reset(kino_TokenBatch *self));

/** @def TokenBatch_Invert(self)
 *
 * Assign positions to constituent Tokens, tallying up the position
 * increments.  Sort the tokens first by token text and then by position
 * ascending.
 */
KINO_METHOD("Kino_TokenBatch_Invert",
void
kino_TokenBatch_invert(kino_TokenBatch *self));

/** @def TokenBatch_Next_Cluster(self, count)
 *
 * Returns a pointer to the next group of like Tokens.  The number of tokens
 * in the cluster will be placed into [count].
 *
 * @param[in] count The number of tokens in the cluster.
 */
KINO_METHOD("Kino_TokenBatch_Next_Cluster",
struct kino_Token**
kino_TokenBatch_next_cluster(kino_TokenBatch *self, kino_u32_t *count));

/** @def TokenBatch_Destroy(self)
 */
KINO_METHOD("Kino_TokenBatch_Destroy",
void
kino_TokenBatch_destroy(kino_TokenBatch *self));

KINO_END_CLASS

#endif /* H_KINO_TOKENBATCH */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

