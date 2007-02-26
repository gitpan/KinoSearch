#ifndef H_KINO_TERMLIST
#define H_KINO_TERMLIST 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_TermList kino_TermList;
typedef struct KINO_TERMLIST_VTABLE KINO_TERMLIST_VTABLE;

struct kino_Term;
struct kino_TermDocs;
struct kino_IntMap;

KINO_CLASS("KinoSearch::Index::TermList", "TermList", 
    "KinoSearch::Util::Obj");

struct kino_TermList {
    KINO_TERMLIST_VTABLE *_;
    kino_u32_t refcount;
};

/* Seek the TermList to the first Term which is lexically greater than
 * or equal to the target.  
 */
KINO_METHOD("Kino_TermList_Seek",
void
kino_TermList_seek(kino_TermList *self, struct kino_Term *term));

/* Proceed to the next term.  Return true until we run out of terms, then
 * return false.
 */
KINO_METHOD("Kino_TermList_Next",
kino_bool_t
kino_TermList_next(kino_TermList *self));

/* Reset the iterator.  TermList_Next() must be called to proceed to the first
 * element.
 */
KINO_METHOD("Kino_TermList_Reset",
void
kino_TermList_reset(kino_TermList* self));

/* Pretend that the iterator is an array, and return the index of the current
 * element.  May return invalid results if the iterator is not in a valid
 * state.
 */
KINO_METHOD("Kino_TermList_Get_Term_Num",
kino_i32_t
kino_TermList_get_term_num(kino_TermList *self));

/* Return the current term.  Will return NULL if the iterator is not in a
 * valid state.
 */
KINO_METHOD("Kino_TermList_Get_Term",
struct kino_Term*
kino_TermList_get_term(kino_TermList *self));

/* Build an IntMap mapping from doc number to term number.  
 *
 * Calling this method leave the iterator in an invalid state.
 */
KINO_METHOD("Kino_TermList_Build_Sort_Cache",
struct kino_IntMap*
kino_TermList_build_sort_cache(kino_TermList *self, 
                               struct kino_TermDocs *term_docs, 
                               kino_u32_t max_doc));

KINO_END_CLASS

#endif /* H_KINO_TERMLIST */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

