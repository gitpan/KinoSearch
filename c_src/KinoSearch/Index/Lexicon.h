#ifndef H_KINO_LEXICON
#define H_KINO_LEXICON 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_Lexicon kino_Lexicon;
typedef struct KINO_LEXICON_VTABLE KINO_LEXICON_VTABLE;

struct kino_Term;
struct kino_IntMap;
struct kino_PostingList;

KINO_CLASS("KinoSearch::Index::Lexicon", "Lex", 
    "KinoSearch::Util::Obj");

struct kino_Lexicon {
    KINO_LEXICON_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
};

/* Seek the Lexicon to the first Term which is lexically greater than
 * or equal to the target.  
 */
void
kino_Lex_seek(kino_Lexicon *self, struct kino_Term *term);
KINO_METHOD("Kino_Lex_Seek");

/* Proceed to the next term.  Return true until we run out of terms, then
 * return false.
 */
chy_bool_t
kino_Lex_next(kino_Lexicon *self);
KINO_METHOD("Kino_Lex_Next");

/* Reset the iterator.  Lex_Next() must be called to proceed to the first
 * element.
 */
void
kino_Lex_reset(kino_Lexicon* self);
KINO_METHOD("Kino_Lex_Reset");

chy_i32_t
kino_Lex_get_size(kino_Lexicon *self);
KINO_METHOD("Kino_Lex_Get_Size");

/* Pretend that the iterator is an array, and return the index of the current
 * element.  May return invalid results if the iterator is not in a valid
 * state.
 */
chy_i32_t
kino_Lex_get_term_num(kino_Lexicon *self);
KINO_METHOD("Kino_Lex_Get_Term_Num");

/* Return the current term.  Will return NULL if the iterator is not in a
 * valid state.
 */
struct kino_Term*
kino_Lex_get_term(kino_Lexicon *self);
KINO_METHOD("Kino_Lex_Get_Term");

/* Build an IntMap mapping from doc number to term number.  
 *
 * Calling this method leaves the iterator in an invalid state.
 */
struct kino_IntMap*
kino_Lex_build_sort_cache(kino_Lexicon *self, 
                          struct kino_PostingList *plist, 
                          chy_u32_t max_doc);
KINO_METHOD("Kino_Lex_Build_Sort_Cache");

/* Pretend the Lexicon is an array and seek the iterator to Term at index
 * [term_num].
 */
void
kino_Lex_seek_by_num(kino_Lexicon *self, chy_i32_t term_num);
KINO_METHOD("Kino_Lex_Seek_By_Num");

KINO_END_CLASS

#endif /* H_KINO_LEXICON */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

