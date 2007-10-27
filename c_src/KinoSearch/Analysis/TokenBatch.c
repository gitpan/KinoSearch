#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TOKENBATCH_VTABLE
#include "KinoSearch/Analysis/TokenBatch.r"

#include "KinoSearch/Analysis/Token.r"
#include "KinoSearch/Index/Term.h"

/* After inversion, record how many like tokens occur in each group.
 */
static void
count_clusters(TokenBatch *self);

TokenBatch*
TokenBatch_new(Token *seed_token) 
{
    TokenBatch *self = (TokenBatch*)VA_new(10);
    self = REALLOCATE(self, 1, TokenBatch);
    self->_ = &TOKENBATCH;

    /* init */
    self->cur                 = 0;
    self->inverted            = false;
    self->cluster_counts      = NULL;
    self->cluster_counts_size = 0;

    /* process the seed token */
    if (seed_token != NULL)
        TokenBatch_append(self, seed_token);

    return self;
}

void            
TokenBatch_destroy(TokenBatch *self)
{       
    free(self->cluster_counts);
    VA_destroy((VArray*)self);
}       

Token*
TokenBatch_next(TokenBatch *self) 
{
    /* kill the iteration if we're out of tokens */
    if (self->cur == self->size)
        return NULL;
    return (Token*)self->elems[ self->cur++ ];
}

void
TokenBatch_reset(TokenBatch *self) 
{
    self->cur = 0;
}

void
TokenBatch_append(TokenBatch *self, Token *token) 
{
    /* safety check */
    if (self->inverted)
        CONFESS("Can't append tokens after inversion");

    /* minimize reallocations */
    if (self->size >= self->cap) {
        if (self->cap < 100) {
            VA_Grow(self, 100);
        }
        else if (self->size < 10000) {
            VA_Grow(self, self->cap * 2);
        }
        else {
            VA_Grow(self, self->cap + 10000);
        }
    }

    /* inlined VA_Push */
    self->elems[ self->size ] = (Obj*)REFCOUNT_INC(token);
    self->size++;
}

Token**
TokenBatch_next_cluster(TokenBatch *self, u32_t *count)
{
    Token **cluster = (Token**)(self->elems + self->cur);

    if (self->cur == self->size) {
        *count = 0;
        return NULL;
    }

    /* don't read past the end of the cluster counts array */
    if (!self->inverted)
        CONFESS("TokenBatch not yet inverted");
    if (self->cur > self->cluster_counts_size)
        CONFESS("Tokens were added after inversion");

    /* place cluster count in passed-in var, advance bookmark */
    *count = self->cluster_counts[ self->cur ];
    self->cur += *count;

    return cluster;
}

void 
TokenBatch_invert(TokenBatch *self)
{
    Token **tokens = (Token**)self->elems;
    Token **limit  = tokens + self->size;
    i32_t   token_pos = 0;

    /* thwart future attempts to append */
    if (self->inverted)
        CONFESS("TokenBatch has already been inverted");
    self->inverted = true;

    /* assign token positions */
    for ( ;tokens < limit; tokens++) {
        Token *const cur_token = *tokens;
        cur_token->pos = token_pos;
        token_pos += cur_token->pos_inc;
        if (token_pos < cur_token->pos) {
            CONFESS("Token positions out of order: %ld %ld", 
                (long)cur_token->pos, (long)token_pos);
        }
    }

    /* sort the tokens lexically, and hand off to cluster counting routine */
    qsort(self->elems, self->size, sizeof(Token*), Token_compare);
    count_clusters(self);
}

static void
count_clusters(TokenBatch *self)
{
    Token **tokens      = (Token**)self->elems;
    u32_t  *counts      = CALLOCATE(self->size + 1, u32_t); 
    u32_t   i;

    /* save the cluster counts */
    self->cluster_counts_size = self->size;
    self->cluster_counts = counts;

    for (i = 0; i < self->size; ) {
        Token *const base_token = tokens[i];
        char  *const base_text  = base_token->text;
        const size_t base_len   = base_token->len;
        u32_t j = i + 1;

        /* iterate through tokens until text doesn't match */
        while (j < self->size) {
            Token *const candidate = tokens[j];

            if (   (candidate->len == base_len)
                && (memcmp(candidate->text, base_text, base_len) == 0)
            ) {
                j++;
            }
            else {
                break;
            }
        }

        /* record a count at the position of the first token in the cluster */
        counts[i] = j - i;

        /* start the next loop at the next token we haven't seen */
        i = j;
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

