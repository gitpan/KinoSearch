#ifndef H_KINO_MULTILEXICON
#define H_KINO_MULTILEXICON 1

#include "KinoSearch/Index/Lexicon.r"

typedef struct kino_MultiLexicon kino_MultiLexicon;
typedef struct KINO_MULTILEXICON_VTABLE KINO_MULTILEXICON_VTABLE;

struct kino_ByteBuf;
struct kino_PriorityQueue;
struct kino_VArray;
struct kino_Term;
struct kino_LexCache;

KINO_CLASS( "KinoSearch::Index::MultiLexicon", "MultiLex", 
    "KinoSearch::Index::Lexicon" );

struct kino_MultiLexicon {
    KINO_MULTILEXICON_VTABLE *_;
    KINO_LEXICON_MEMBER_VARS;
    struct kino_ByteBuf        *field;
    struct kino_Term           *term;
    struct kino_PriorityQueue  *lex_q;
    struct kino_VArray         *seg_lexicons;
    struct kino_LexCache       *lex_cache;
    chy_i32_t                   term_num;
};

/* Constructor.  [lex_cache] may be NULL.
 */
kino_MultiLexicon*
kino_MultiLex_new(const struct kino_ByteBuf *field, 
                  struct kino_VArray *seg_lexicons,
                  struct kino_LexCache *lex_cache);

/* Note: Seek may only be called if the object has a LexCache.
 */
void
kino_MultiLex_seek(kino_MultiLexicon *self, struct kino_Term *term);
KINO_METHOD("Kino_MultiLex_Seek");

chy_bool_t
kino_MultiLex_next(kino_MultiLexicon *self);
KINO_METHOD("Kino_MultiLex_Next");

void
kino_MultiLex_reset(kino_MultiLexicon *self);
KINO_METHOD("Kino_MultiLex_Reset");

chy_i32_t 
kino_MultiLex_get_term_num(kino_MultiLexicon *self);
KINO_METHOD("Kino_MultiLex_Get_Term_Num");

struct kino_Term*
kino_MultiLex_get_term(kino_MultiLexicon *self);
KINO_METHOD("Kino_MultiLex_Get_Term");

struct kino_IntMap*
kino_MultiLex_build_sort_cache(kino_MultiLexicon *self, 
                               struct kino_PostingList *plist, 
                               chy_u32_t max_doc);
KINO_METHOD("Kino_MultiLex_Build_Sort_Cache");

void
kino_MultiLex_destroy(kino_MultiLexicon *self);
KINO_METHOD("Kino_MultiLex_Destroy");

KINO_END_CLASS

#endif /* H_KINO_MULTILEXICON */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

