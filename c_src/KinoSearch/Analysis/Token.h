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
    kino_u32_t  start_offset;
    kino_u32_t  end_offset;
    float       boost;
    kino_i32_t  pos_inc;
    kino_i32_t  pos;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_Token*
kino_Token_new(const char *text, size_t len, kino_u32_t start_offset, 
               kino_u32_t end_offset, float boost, kino_i32_t pos_inc));

/* qsort-compatible comparison routine.
 */
KINO_FUNCTION(
int
kino_Token_compare(const void *va, const void *vb));

KINO_METHOD("Kino_Token_Destroy",
void 
kino_Token_destroy(kino_Token *token));

KINO_END_CLASS

#endif /* H_KINO_TOKEN */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

