#ifndef H_KINO_SEGLEXICON
#define H_KINO_SEGLEXICON 1

#include "KinoSearch/Index/Lexicon.r"

typedef struct kino_SegLexicon kino_SegLexicon;
typedef struct KINO_SEGLEXICON_VTABLE KINO_SEGLEXICON_VTABLE;

struct kino_ByteBuf;
struct kino_Schema;
struct kino_Folder;
struct kino_InStream;
struct kino_SegInfo;
struct kino_SegLexCache;
struct kino_Term;
struct kino_TermInfo;
struct kino_TermStepper;

KINO_CLASS("KinoSearch::Index::SegLexicon", "SegLex", 
    "KinoSearch::Index::Lexicon");

struct kino_SegLexicon {
    KINO_SEGLEXICON_VTABLE *_;
    KINO_LEXICON_MEMBER_VARS;

    struct kino_Schema           *schema;
    struct kino_Folder           *folder;
    struct kino_SegInfo          *seg_info;
    struct kino_TermStepper      *term_stepper;
    struct kino_InStream         *instream;
    struct kino_SegLexCache      *lex_cache;
    struct kino_ByteBuf          *field;
    chy_i32_t                     field_num;
    chy_i32_t                     size;
    chy_i32_t                     term_num;
    chy_i32_t                     skip_interval;
    chy_i32_t                     index_interval;
    chy_bool_t                    is_index;
};

/* Constructor. [lex_cache] may be NULL, but in that case, the SegLexicon will
 * not be able to seek().
 */
kino_SegLexicon*
kino_SegLex_new(struct kino_Schema *schema, struct kino_Folder *folder,
                struct kino_SegInfo *seg_info, 
                const struct kino_ByteBuf *field,
                struct kino_SegLexCache *lex_cache,
                chy_bool_t is_index);

void
kino_SegLex_destroy(kino_SegLexicon *self);
KINO_METHOD("Kino_SegLex_Destroy");

void
kino_SegLex_seek(kino_SegLexicon*self, struct kino_Term *term);
KINO_METHOD("Kino_SegLex_Seek");

void
kino_SegLex_reset(kino_SegLexicon* self);
KINO_METHOD("Kino_SegLex_Reset");

struct kino_TermInfo*
kino_SegLex_get_term_info(kino_SegLexicon *self);
KINO_METHOD("Kino_SegLex_Get_Term_Info");

chy_bool_t
kino_SegLex_next(kino_SegLexicon *self);
KINO_METHOD("Kino_SegLex_Next");

chy_i32_t
kino_SegLex_get_field_num(kino_SegLexicon *self);
KINO_METHOD("Kino_SegLex_Get_Field_Num");

chy_i32_t
kino_SegLex_get_size(kino_SegLexicon *self);
KINO_METHOD("Kino_SegLex_Get_Size");

chy_i32_t
kino_SegLex_get_term_num(kino_SegLexicon *self);
KINO_METHOD("Kino_SegLex_Get_Term_Num");

struct kino_Term*
kino_SegLex_get_term(kino_SegLexicon *self);
KINO_METHOD("Kino_SegLex_Get_Term");

struct kino_IntMap*
kino_SegLex_build_sort_cache(kino_SegLexicon *self, 
                             struct kino_PostingList *plist,
                             chy_u32_t size);
KINO_METHOD("Kino_SegLex_Build_Sort_Cache");

void
kino_SegLex_seek_by_num(kino_SegLexicon *self, chy_i32_t term_num);
KINO_METHOD("Kino_SegLex_Seek_By_Num");

kino_SegLexicon*
kino_SegLex_clone(kino_SegLexicon *self);
KINO_METHOD("Kino_SegLex_Clone");

KINO_END_CLASS

#endif /* H_KINO_SEGLEXICON */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

