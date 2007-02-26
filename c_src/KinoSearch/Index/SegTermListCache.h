#ifndef H_KINO_SEGTERMLISTCACHE
#define H_KINO_SEGTERMLISTCACHE 1

#include "KinoSearch/Index/TermListCache.r"

typedef struct kino_SegTermListCache kino_SegTermListCache;
typedef struct KINO_SEGTERMLISTCACHE_VTABLE KINO_SEGTERMLISTCACHE_VTABLE;

struct kino_ByteBuf;
struct kino_Schema;
struct kino_Folder;
struct kino_SegInfo;
struct kino_SegTermList;
struct kino_Term;
struct kino_TermInfo;

KINO_CLASS("KinoSearch::Index::SegTermListCache", "SegTLCache", 
    "KinoSearch::Index::TermListCache");

struct kino_SegTermListCache {
    KINO_SEGTERMLISTCACHE_VTABLE *_;
    kino_u32_t refcount;
    KINO_TERMLISTCACHE_MEMBER_VARS

    struct kino_TermInfo   **tinfos;
    struct kino_Schema      *schema;
    struct kino_Folder      *folder;
    struct kino_SegInfo     *seg_info;
    kino_i32_t               field_num;
    kino_bool_t              locked;
};

/* Constructor.  Will return NULL if the field is not indexed or if no terms
 * are present for this field in this segment.
 */
KINO_FUNCTION(
kino_SegTermListCache*
kino_SegTLCache_new(struct kino_Schema *schema, struct kino_Folder *folder,
                    struct kino_SegInfo *seg_info, 
                    const struct kino_ByteBuf *field));

/* Because the a SegTermListCache object is shared, it is necessary to lock
 * before seeking and unlock after all information is retrieved.
 */
KINO_METHOD("Kino_SegTLCache_Lock",
void
kino_SegTLCache_lock(kino_SegTermListCache *self));

KINO_METHOD("Kino_SegTLCache_Unlock",
void
kino_SegTLCache_unlock(kino_SegTermListCache *self));

KINO_METHOD("Kino_SegTLCache_Destroy",
void
kino_SegTLCache_destroy(kino_SegTermListCache *self));

/* Return a pointer to the term info after seeking.
 */
KINO_METHOD("Kino_SegTLCache_Get_Term_Info",
struct kino_TermInfo*
kino_SegTLCache_get_term_info(kino_SegTermListCache *self));

KINO_END_CLASS

#endif /* H_KINO_SEGTERMLISTCACHE */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

