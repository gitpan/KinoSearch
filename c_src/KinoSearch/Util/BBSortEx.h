#ifndef H_KINO_BBSORTEX
#define H_KINO_BBSORTEX 1

#include "KinoSearch/Util/SortExternal.r"

typedef struct kino_BBSortEx kino_BBSortEx;
typedef struct KINO_BBSORTEX_VTABLE KINO_BBSORTEX_VTABLE;

struct kino_BBSortExRun;

KINO_FINAL_CLASS("KinoSearch::Util::BBSortEx", "BBSortEx",
    "KinoSearch::Util::SortExternal");

struct kino_BBSortEx {
    KINO_BBSORTEX_VTABLE *_;
    KINO_SORTEXTERNAL_MEMBER_VARS;
    struct kino_ByteBuf   *sortfile_name;
    struct kino_OutStream *outstream;
    struct kino_InStream  *instream;
    struct kino_InvIndex  *invindex;
    struct kino_SegInfo   *seg_info;
};

/* Constructor. 
 */
kino_BBSortEx*
kino_BBSortEx_new(struct kino_InvIndex *invindex, 
                  struct kino_SegInfo *seg_info, 
                  chy_u32_t mem_threshold);

/* Wrapper around BB_compare which allows (superfluous) context argument.
 */
int
kino_BBSortEx_compare_bbs(void *context, const void *va, const void *vb);

/* Create a new ByteBuf and feed it into the sortex.
 */
void
kino_BBSortEx_feed_str(kino_BBSortEx *self, char *ptr, chy_u32_t len);
KINO_METHOD("Kino_BBSortEx_Feed_Str");

void
kino_BBSortEx_flush(kino_BBSortEx *self);
KINO_METHOD("Kino_BBSortEx_Flush");

void
kino_BBSortEx_flip(kino_BBSortEx *self);
KINO_METHOD("Kino_BBSortEx_Flip");

void
kino_BBSortEx_destroy(kino_BBSortEx *self);
KINO_METHOD("Kino_BBSortEx_Destroy");

KINO_END_CLASS

#endif /* H_KINO_BBSORTEX */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

