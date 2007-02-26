#ifndef H_KINO_TERMINFO
#define H_KINO_TERMINFO 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_TermInfo kino_TermInfo;
typedef struct KINO_TERMINFO_VTABLE KINO_TERMINFO_VTABLE;

KINO_FINAL_CLASS("KinoSearch::Index::TermInfo", "TInfo", 
    "KinoSearch::Util::Obj");

struct kino_TermInfo {
    KINO_TERMINFO_VTABLE *_;
    kino_u32_t refcount;
    kino_i32_t field_num;
    kino_i32_t doc_freq;
    kino_u64_t post_fileptr;
    kino_i32_t skip_offset;
    kino_u64_t index_fileptr;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_TermInfo*
kino_TInfo_new(kino_i32_t field_num,
               kino_i32_t doc_freq,
               kino_u64_t post_fileptr,
               kino_i32_t skip_offset,
               kino_u64_t index_fileptr));

/* "Zero out" the TermInfo.
 */
KINO_METHOD("Kino_TInfo_Reset",
void
kino_TInfo_reset(kino_TermInfo *self)); 

KINO_METHOD("Kino_TInfo_Copy",
void
kino_TInfo_copy(kino_TermInfo *self, kino_TermInfo *other));

KINO_METHOD("Kino_TInfo_Clone",
kino_TermInfo*
kino_TInfo_clone(kino_TermInfo *self));

KINO_END_CLASS

#endif /* H_KINO_TERMINFO */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

