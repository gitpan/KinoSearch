#ifndef H_KINO_MULTITERMLIST
#define H_KINO_MULTITERMLIST 1

#include "KinoSearch/Index/TermList.r"

typedef struct kino_MultiTermList kino_MultiTermList;
typedef struct KINO_MULTITERMLIST_VTABLE KINO_MULTITERMLIST_VTABLE;

struct kino_ByteBuf;
struct kino_PriorityQueue;
struct kino_VArray;
struct kino_Term;
struct kino_TermListCache;

KINO_CLASS( "KinoSearch::Index::MultiTermList", "MultiTermList", 
    "KinoSearch::Index::TermList" );

struct kino_MultiTermList {
    KINO_MULTITERMLIST_VTABLE *_;
    kino_u32_t refcount;
    KINO_TERMLIST_MEMBER_VARS
    struct kino_ByteBuf        *field;
    struct kino_Term           *term;
    struct kino_PriorityQueue  *list_q;
    struct kino_VArray         *seg_term_lists;
    struct kino_TermListCache  *tl_cache;
    kino_i32_t                  term_num;
};

/* Constructor.  [tl_cache] may be NULL.
 */
KINO_FUNCTION(
kino_MultiTermList*
kino_MultiTermList_new(const struct kino_ByteBuf *field, 
                       struct kino_VArray *seg_term_lists,
                       struct kino_TermListCache *tl_cache));

/* Note: Seek may only be called if the object has a TermListCache.
 */
KINO_METHOD("Kino_MultiTermList_Seek",
void
kino_MultiTermList_seek(kino_MultiTermList *self, struct kino_Term *term));

KINO_METHOD("Kino_MultiTermList_Next",
kino_bool_t
kino_MultiTermList_next(kino_MultiTermList *self));

KINO_METHOD("Kino_MultiTermList_Reset",
void
kino_MultiTermList_reset(kino_MultiTermList *self));

KINO_METHOD("Kino_MultiTermList_Get_Term_Num",
kino_i32_t 
kino_MultiTermList_get_term_num(kino_MultiTermList *self));

KINO_METHOD("Kino_MultiTermList_Get_Term",
struct kino_Term*
kino_MultiTermList_get_term(kino_MultiTermList *self));

KINO_METHOD("Kino_MultiTermList_Build_Sort_Cache",
struct kino_IntMap*
kino_MultiTermList_build_sort_cache(kino_MultiTermList *self, 
                                    struct kino_TermDocs *term_docs, 
                                    kino_u32_t max_doc));

KINO_METHOD("Kino_MultiTermList_Destroy",
void
kino_MultiTermList_destroy(kino_MultiTermList *self));

KINO_END_CLASS

#endif /* H_KINO_MULTITERMLIST */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

