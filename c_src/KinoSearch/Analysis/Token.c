#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TOKEN_VTABLE
#include "KinoSearch/Analysis/Token.r"

Token*
Token_new(const char* text, size_t len, u32_t start_offset, u32_t end_offset, 
          float boost, i32_t pos_inc) 
{
    CREATE(self, Token, TOKEN);

    /* allocate and assign */
    self->text = StrHelp_strndup(text, len);

    /* assign */
    self->len          = len;
    self->start_offset = start_offset;
    self->end_offset   = end_offset;
    self->boost        = boost;
    self->pos_inc      = pos_inc;

    /* init */
    self->pos = -1;

    return self;
}

int
Token_compare(const void *va, const void *vb)
{
    Token *const a = *((Token**)va);
    Token *const b = *((Token**)vb);
    
    size_t min_len = a->len < b->len ? a->len : b->len;

    int comparison = memcmp(a->text, b->text, min_len); 

    if (comparison == 0) {
        if (a->len != b->len) {
            comparison = a->len < b->len ? -1 : 1;
        }
        else {
            comparison = a->pos < b->pos ? -1 : 1;
        }
    }

    return comparison;
}


void
Token_destroy(Token *self) 
{
    free(self->text);
    free(self);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

