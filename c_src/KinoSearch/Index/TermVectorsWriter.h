#ifndef H_KINO_TERMVECTORSWRITER
#define H_KINO_TERMVECTORSWRITER 1

#include "KinoSearch/Util/Obj.r"

struct kino_InvIndex;
struct kino_SegInfo;
struct kino_ByteBuf;
struct kino_DocVector;
struct kino_TermVectorsReader;
struct kino_TokenBatch;
struct kino_IntMap;

typedef struct kino_TermVectorsWriter kino_TermVectorsWriter;
typedef struct KINO_TERMVECTORSWRITER_VTABLE KINO_TERMVECTORSWRITER_VTABLE;

#define KINO_TVWRITER_FORMAT 1

KINO_FINAL_CLASS("KinoSearch::Index::TermVectorsWriter", "TVWriter", 
    "KinoSearch::Util::Obj");

struct kino_TermVectorsWriter {
    KINO_TERMVECTORSWRITER_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_InvIndex  *invindex;
    struct kino_SegInfo   *seg_info;
    struct kino_OutStream *tv_out;
    struct kino_OutStream *tvx_out;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_TermVectorsWriter*
kino_TVWriter_new(struct kino_InvIndex *invindex, 
                  struct kino_SegInfo *seg_info));

KINO_METHOD("Kino_TVWriter_Add_Segment",
void
kino_TVWriter_add_segment(kino_TermVectorsWriter *self, 
                          struct kino_TermVectorsReader *tv_reader,
                          struct kino_IntMap *doc_map,
                          kino_u32_t max_doc));
                          
KINO_METHOD("Kino_TVWriter_Finish",
void
kino_TVWriter_finish(kino_TermVectorsWriter *self));

KINO_METHOD("Kino_TVWriter_TV_String",
struct kino_ByteBuf*
kino_TVWriter_tv_string(kino_TermVectorsWriter *self, 
                        struct kino_TokenBatch *batch));

KINO_METHOD("Kino_TVWriter_Destroy",
void
kino_TVWriter_destroy(kino_TermVectorsWriter *self));

KINO_END_CLASS

#ifdef KINO_USE_SHORT_NAMES
  #define TVWRITER_FORMAT KINO_TVWRITER_FORMAT
#endif

#endif /* H_KINO_TERMVECTORSWRITER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

