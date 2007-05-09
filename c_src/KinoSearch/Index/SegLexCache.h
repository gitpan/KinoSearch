#ifndef H_KINO_SEGLEXCACHE
#define H_KINO_SEGLEXCACHE 1

#include "KinoSearch/Index/LexCache.r"

typedef struct kino_SegLexCache kino_SegLexCache;
typedef struct KINO_SEGLEXCACHE_VTABLE KINO_SEGLEXCACHE_VTABLE;

struct kino_ByteBuf;
struct kino_Schema;
struct kino_Folder;
struct kino_SegInfo;
struct kino_SegLexicon;
struct kino_Term;
struct kino_TermInfo;

KINO_CLASS("KinoSearch::Index::SegLexCache", "SegLexCache", 
    "KinoSearch::Index::LexCache");

struct kino_SegLexCache {
    KINO_SEGLEXCACHE_VTABLE *_;
    KINO_LEXCACHE_MEMBER_VARS;

    struct kino_TermInfo   **tinfos;
    struct kino_Schema      *schema;
    struct kino_Folder      *folder;
    struct kino_SegInfo     *seg_info;
    chy_i32_t                field_num;
    chy_bool_t               locked;
};

/* Constructor.  Will return NULL if the field is not indexed or if no terms
 * are present for this field in this segment.
 */
kino_SegLexCache*
kino_SegLexCache_new(struct kino_Schema *schema, struct kino_Folder *folder,
                    struct kino_SegInfo *seg_info, 
                    const struct kino_ByteBuf *field);

/* Because the a SegLexCache object is shared, it is necessary to lock
 * before seeking and unlock after all information is retrieved.
 */
void
kino_SegLexCache_lock(kino_SegLexCache *self);
KINO_METHOD("Kino_SegLexCache_Lock");

void
kino_SegLexCache_unlock(kino_SegLexCache *self);
KINO_METHOD("Kino_SegLexCache_Unlock");

void
kino_SegLexCache_destroy(kino_SegLexCache *self);
KINO_METHOD("Kino_SegLexCache_Destroy");

/* Return a pointer to the term info after seeking.
 */
struct kino_TermInfo*
kino_SegLexCache_get_term_info(kino_SegLexCache *self);
KINO_METHOD("Kino_SegLexCache_Get_Term_Info");

KINO_END_CLASS

#endif /* H_KINO_SEGLEXCACHE */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

