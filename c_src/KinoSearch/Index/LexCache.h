#ifndef H_KINO_LEXCACHE
#define H_KINO_LEXCACHE 1

#include "KinoSearch/Index/Lexicon.r"

typedef struct kino_LexCache kino_LexCache;
typedef struct KINO_LEXCACHE_VTABLE KINO_LEXCACHE_VTABLE;

struct kino_ByteBuf;
struct kino_Term;

KINO_CLASS("KinoSearch::Index::LexCache", "LexCache", 
    "KinoSearch::Index::Lexicon");

struct kino_LexCache {
    KINO_LEXCACHE_VTABLE *_;
    KINO_LEXICON_MEMBER_VARS;

    struct kino_ByteBuf    **term_texts;
    struct kino_Term        *term;
    struct kino_ByteBuf     *field;
    chy_i32_t                tick;
    chy_i32_t                size;
    chy_i32_t                index_interval;
};

/* Constructor.  Takes ownership of the [term_texts] array (1 refcount per
 * ByteBuf).
 */
kino_LexCache*
kino_LexCache_new(struct kino_ByteBuf *field, 
                  struct kino_ByteBuf **term_texts,
                  chy_i32_t size, chy_i32_t index_interval);

void
kino_LexCache_seek(kino_LexCache *self, struct kino_Term *term);
KINO_METHOD("Kino_LexCache_Seek");

void
kino_LexCache_destroy(kino_LexCache *self);
KINO_METHOD("Kino_LexCache_Destroy");

chy_i32_t
kino_LexCache_get_term_num(kino_LexCache *self);
KINO_METHOD("Kino_LexCache_Get_Term_Num");

struct kino_Term*
kino_LexCache_get_term(kino_LexCache *self);
KINO_METHOD("Kino_LexCache_Get_Term");

KINO_END_CLASS

#endif /* H_KINO_LEXCACHE */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

