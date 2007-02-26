#ifndef H_KINO_TOKENBATCH
#define H_KINO_TOKENBATCH 1

#include "KinoSearch/Util/VArray.r"

struct kino_Token;
struct kino_ByteBuf;

typedef struct kino_TokenBatch kino_TokenBatch;
typedef struct KINO_TOKENBATCH_VTABLE KINO_TOKENBATCH_VTABLE;

KINO_CLASS("KinoSearch::Analysis::TokenBatch", "TokenBatch", 
    "KinoSearch::Util::VArray");

struct kino_TokenBatch {
    KINO_TOKENBATCH_VTABLE *_;
    kino_u32_t refcount;
    KINO_VARRAY_MEMBER_VARS
    kino_u32_t cur; /* pointer to current token */
    kino_bool_t inverted;
    kino_u32_t *cluster_counts;
    kino_u32_t  cluster_counts_size;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_TokenBatch* 
kino_TokenBatch_new(struct kino_Token *seed_token));

/* (See Perl-space docs.)
 */
KINO_METHOD("Kino_TokenBatch_Append",
void
kino_TokenBatch_append(kino_TokenBatch *self, struct kino_Token *token));

/* (See Perl-space docs.)
 */
KINO_METHOD("Kino_TokenBatch_Next",
struct kino_Token*
kino_TokenBatch_next(kino_TokenBatch *self));

/* Return the TokenBatch's iterator to a uninitialized state.
 */
KINO_METHOD("Kino_TokenBatch_Reset",
void
kino_TokenBatch_reset(kino_TokenBatch *self));

/* Assign positions to constituent Tokens, tallying up the position
 * increments.  Sort the tokens first by token text and then by position
 * ascending.
 */
KINO_METHOD("Kino_TokenBatch_Invert",
void
kino_TokenBatch_invert(kino_TokenBatch *self));

/* Returns a pointer to the next group of like Tokens.  The number of tokens
 * in the cluster will be placed into [count].
 */
KINO_METHOD("Kino_TokenBatch_Next_Cluster",
struct kino_Token**
kino_TokenBatch_next_cluster(kino_TokenBatch *self, kino_u32_t *count));

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

