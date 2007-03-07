#ifndef H_KINO_SEGTERMLIST
#define H_KINO_SEGTERMLIST 1

#include "KinoSearch/Index/TermList.r"

typedef struct kino_SegTermList kino_SegTermList;
typedef struct KINO_SEGTERMLIST_VTABLE KINO_SEGTERMLIST_VTABLE;

struct kino_ByteBuf;
struct kino_Schema;
struct kino_Folder;
struct kino_InStream;
struct kino_SegInfo;
struct kino_SegTermListCache;
struct kino_Term;
struct kino_TermInfo;

KINO_CLASS("KinoSearch::Index::SegTermList", "SegTermList", 
    "KinoSearch::Index::TermList");

struct kino_SegTermList {
    KINO_SEGTERMLIST_VTABLE *_;
    KINO_TERMLIST_MEMBER_VARS;

    struct kino_Schema           *schema;
    struct kino_Folder           *folder;
    struct kino_SegInfo          *seg_info;
    struct kino_Term             *term;
    struct kino_TermInfo         *tinfo;
    struct kino_InStream         *instream;
    struct kino_SegTermListCache *tl_cache;
    struct kino_ByteBuf          *field;
    kino_i32_t                    field_num;
    kino_i32_t                    size;
    kino_i32_t                    term_num;
    kino_i32_t                    skip_interval;
    kino_i32_t                    index_interval;
    kino_bool_t                   is_index;
};

/* Constructor. [tl_cache] may be NULL, but in that case, the SegTermList will
 * not be able to seek().
 */
KINO_FUNCTION(
kino_SegTermList*
kino_SegTermList_new(struct kino_Schema *schema, struct kino_Folder *folder,
                     struct kino_SegInfo *seg_info, 
                     const struct kino_ByteBuf *field,
                     struct kino_SegTermListCache *tl_cache,
                     kino_bool_t is_index));

KINO_METHOD("Kino_SegTermList_Destroy",
void
kino_SegTermList_destroy(kino_SegTermList *self));

KINO_METHOD("Kino_SegTermList_Seek",
void
kino_SegTermList_seek(kino_SegTermList*self, struct kino_Term *term));

KINO_METHOD("Kino_SegTermList_Reset",
void
kino_SegTermList_reset(kino_SegTermList* self));

KINO_METHOD("Kino_SegTermList_Get_Term_Info",
struct kino_TermInfo*
kino_SegTermList_get_term_info(kino_SegTermList *self));

KINO_METHOD("Kino_SegTermList_Next",
kino_bool_t
kino_SegTermList_next(kino_SegTermList *self));

KINO_METHOD("Kino_SegTermList_Get_Field_Num",
kino_i32_t
kino_SegTermList_get_field_num(kino_SegTermList *self));

KINO_METHOD("Kino_SegTermList_Get_Term_Num",
kino_i32_t
kino_SegTermList_get_term_num(kino_SegTermList *self));

KINO_METHOD("Kino_SegTermList_Get_Term",
struct kino_Term*
kino_SegTermList_get_term(kino_SegTermList *self));

KINO_METHOD("Kino_SegTermList_Build_Sort_Cache",
struct kino_IntMap*
kino_SegTermList_build_sort_cache(kino_SegTermList *self, 
                                  struct kino_TermDocs *term_docs, 
                                  kino_u32_t size));

KINO_METHOD("Kino_SegTermList_Clone",
kino_SegTermList*
kino_SegTermList_clone(kino_SegTermList *self));

KINO_END_CLASS

#endif /* H_KINO_SEGTERMLIST */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

