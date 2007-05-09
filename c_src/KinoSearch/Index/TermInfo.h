#ifndef H_KINO_TERMINFO
#define H_KINO_TERMINFO 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_TermInfo kino_TermInfo;
typedef struct KINO_TERMINFO_VTABLE KINO_TERMINFO_VTABLE;

KINO_FINAL_CLASS("KinoSearch::Index::TermInfo", "TInfo", 
    "KinoSearch::Util::Obj");

struct kino_TermInfo {
    KINO_TERMINFO_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    chy_i32_t doc_freq;
    chy_u64_t post_filepos;
    chy_u64_t skip_filepos;
    chy_u64_t index_filepos;
};

/* Constructor.
 */
kino_TermInfo*
kino_TInfo_new(chy_i32_t doc_freq,
               chy_u64_t post_filepos,
               chy_u64_t skip_filepos,
               chy_u64_t index_filepos);

/* "Zero out" the TermInfo.
 */
void
kino_TInfo_reset(kino_TermInfo *self);
KINO_METHOD("Kino_TInfo_Reset");

void
kino_TInfo_copy(kino_TermInfo *self, const kino_TermInfo *other);
KINO_METHOD("Kino_TInfo_Copy");

kino_TermInfo*
kino_TInfo_clone(kino_TermInfo *self);
KINO_METHOD("Kino_TInfo_Clone");

struct kino_ByteBuf*
kino_TInfo_to_string(kino_TermInfo *self);
KINO_METHOD("Kino_TInfo_To_String");

KINO_END_CLASS

#endif /* H_KINO_TERMINFO */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

