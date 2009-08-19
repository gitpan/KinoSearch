#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Analysis/Token.h"

Token*
Token_new(const char* text, size_t len, u32_t start_offset, u32_t end_offset, 
          float boost, i32_t pos_inc) 
{
    Token *self = (Token*)VTable_Make_Obj(TOKEN);
    return Token_init(self, text, len, start_offset, end_offset, boost,
        pos_inc);
}

Token*
Token_init(Token *self, const char* text, size_t len, u32_t start_offset, 
           u32_t end_offset, float boost, i32_t pos_inc) 
{
    /* Allocate and assign. */
    self->text = StrHelp_strndup(text, len);

    /* Assign. */
    self->len          = len;
    self->start_offset = start_offset;
    self->end_offset   = end_offset;
    self->boost        = boost;
    self->pos_inc      = pos_inc;

    /* Init. */
    self->pos = -1;

    return self;
}

void
Token_destroy(Token *self) 
{
    FREEMEM(self->text);
    SUPER_DESTROY(self, TOKEN);
}

int
Token_compare(void *context, const void *va, const void *vb)
{
    Token *const a = *((Token**)va);
    Token *const b = *((Token**)vb);
    size_t min_len = a->len < b->len ? a->len : b->len;
    int comparison = memcmp(a->text, b->text, min_len); 
    UNUSED_VAR(context);

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

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

