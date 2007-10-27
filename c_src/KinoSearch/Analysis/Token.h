#ifndef H_KINO_TOKEN
#define H_KINO_TOKEN 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_Token kino_Token;
typedef struct KINO_TOKEN_VTABLE KINO_TOKEN_VTABLE;

KINO_CLASS("KinoSearch::Analysis::Token", "Token", "KinoSearch::Util::Obj");

struct kino_Token {
    KINO_TOKEN_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    char       *text;
    size_t      len;
    chy_u32_t   start_offset;
    chy_u32_t   end_offset;
    float       boost;
    chy_i32_t   pos_inc;
    chy_i32_t   pos;
};

/* Constructor.
 */
kino_Token*
kino_Token_new(const char *text, size_t len, chy_u32_t start_offset, 
               chy_u32_t end_offset, float boost, chy_i32_t pos_inc);

/* qsort-compatible comparison routine.
 */
int
kino_Token_compare(const void *va, const void *vb);

void 
kino_Token_destroy(kino_Token *token);
KINO_METHOD("Kino_Token_Destroy");

KINO_END_CLASS

#endif /* H_KINO_TOKEN */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

