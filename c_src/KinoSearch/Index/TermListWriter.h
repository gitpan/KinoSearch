#ifndef H_KINO_TERMLISTWRITER
#define H_KINO_TERMLISTWRITER 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_TermListWriter kino_TermListWriter;
typedef struct KINO_TERMLISTWRITER_VTABLE KINO_TERMLISTWRITER_VTABLE;

struct kino_ByteBuf;
struct kino_Hash;
struct kino_InvIndex;
struct kino_OutStream;
struct kino_TermInfo;
struct kino_SegInfo;

KINO_FINAL_CLASS("KinoSearch::Index::TermListWriter", "TLWriter", 
    "KinoSearch::Util::Obj");

struct kino_TermListWriter {
    KINO_TERMLISTWRITER_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_InvIndex  *invindex;
    struct kino_SegInfo   *seg_info;
    struct kino_OutStream *fh;
    struct kino_ByteBuf   *filename;
    struct kino_Hash      *counts;
    kino_i32_t             is_index;
    kino_i32_t             index_interval;
    kino_i32_t             skip_interval;
    kino_TermListWriter  *other;
    struct kino_ByteBuf   *last_text;
    struct kino_TermInfo  *last_tinfo;
    kino_u64_t             last_tl_ptr;
    kino_i64_t             size;
};

/* Constructor. 
 */
KINO_FUNCTION(
kino_TermListWriter*
kino_TLWriter_new(struct kino_InvIndex *invindex, 
                  struct kino_SegInfo *seg_info,
                  kino_i32_t is_index, kino_i32_t index_interval, 
                  kino_i32_t skip_interval));

/* Add a Term's text and its associated TermInfo (which has the Term's 
 * field number).
 */
KINO_METHOD("Kino_TLWriter_Add",
void 
kino_TLWriter_add(kino_TermListWriter* self, 
                  struct kino_ByteBuf* term_text,
                  struct kino_TermInfo* tinfo));

/* Conclude business.
 */
KINO_METHOD("Kino_TLWriter_Finish",
void
kino_TLWriter_finish(kino_TermListWriter *self));

KINO_METHOD("Kino_TLWriter_Destroy",
void
kino_TLWriter_destroy(kino_TermListWriter *self));

KINO_END_CLASS

#endif /* H_KINO_TERMLISTWRITER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

