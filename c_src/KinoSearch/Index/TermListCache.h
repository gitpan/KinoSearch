#ifndef H_KINO_TERMLISTCACHE
#define H_KINO_TERMLISTCACHE 1

#include "KinoSearch/Index/TermList.r"

typedef struct kino_TermListCache kino_TermListCache;
typedef struct KINO_TERMLISTCACHE_VTABLE KINO_TERMLISTCACHE_VTABLE;

struct kino_ByteBuf;
struct kino_Term;

KINO_CLASS("KinoSearch::Index::TermListCache", "TLCache", 
    "KinoSearch::Index::TermList");

struct kino_TermListCache {
    KINO_TERMLISTCACHE_VTABLE *_;
    KINO_TERMLIST_MEMBER_VARS;

    struct kino_ByteBuf    **term_texts;
    struct kino_Term        *term;
    struct kino_ByteBuf     *field;
    kino_i32_t               tick;
    kino_i32_t               size;
    kino_i32_t               index_interval;
};

/* Constructor.  Takes ownership of the [term_texts] array (1 refcount per
 * ByteBuf).
 */
KINO_FUNCTION(
kino_TermListCache*
kino_TLCache_new(struct kino_ByteBuf *field, struct kino_ByteBuf **term_texts,
                 kino_i32_t size, kino_i32_t index_interval));

KINO_METHOD("Kino_TLCache_Seek",
void
kino_TLCache_seek(kino_TermListCache *self, struct kino_Term *term));

KINO_METHOD("Kino_TLCache_Destroy",
void
kino_TLCache_destroy(kino_TermListCache *self));

KINO_METHOD("Kino_TLCache_Get_Term_Num",
kino_i32_t
kino_TLCache_get_term_num(kino_TermListCache *self));

KINO_METHOD("Kino_TLCache_Get_Term",
struct kino_Term*
kino_TLCache_get_term(kino_TermListCache *self));

KINO_END_CLASS

#endif /* H_KINO_TERMLISTCACHE */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

