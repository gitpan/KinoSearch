#ifndef H_KINO_POSTINGSWRITER
#define H_KINO_POSTINGSWRITER 1

#include "KinoSearch/Util/Obj.r"

struct kino_TokenBatch;
struct kino_FieldSpec;
struct kino_InvIndex;
struct kino_TermListWriter;
struct kino_SortExternal;
struct kino_SegTermDocs;
struct kino_TermListReader;
struct kino_IntMap;
struct kino_SegInfo;

typedef struct kino_PostingsWriter kino_PostingsWriter;
typedef struct KINO_POSTINGSWRITER_VTABLE KINO_POSTINGSWRITER_VTABLE;

KINO_FINAL_CLASS("KinoSearch::Index::PostingsWriter", "PostWriter", 
    "KinoSearch::Util::Obj");

struct kino_PostingsWriter {
    KINO_POSTINGSWRITER_VTABLE *_;
    kino_u32_t refcount;
    struct kino_InvIndex      *invindex;
    struct kino_SegInfo       *seg_info;
    struct kino_SortExternal  *sort_pool;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_PostingsWriter*
kino_PostWriter_new(struct kino_InvIndex *invindex, 
                    struct kino_SegInfo *seg_info));

/* Helper function for the Perl-space function write_postings().
 */
KINO_METHOD("Kino_PostWriter_Write_Postings",
void
kino_PostWriter_write_postings(kino_PostingsWriter *self,
                               struct kino_TermListWriter *tl_writer));

/* Add a field's content, in the form of an inverted TokenBatch.
 */
KINO_METHOD("Kino_PostWriter_Add_Batch",
void
kino_PostWriter_add_batch(kino_PostingsWriter *self, 
                          struct kino_TokenBatch *batch, 
                          struct kino_FieldSpec *field_spec,
                          kino_i32_t doc_num, 
                          float doc_boost, 
                          float length_norm));

/* Helper function for the Perl-space function add_segment().
 */
KINO_METHOD("Kino_PostWriter_Add_Segment",
void
kino_PostWriter_add_segment(kino_PostingsWriter *self, 
                            struct kino_TermListReader* tl_reader, 
                            struct kino_SegTermDocs *term_docs, 
                            struct kino_IntMap *doc_map,
                            struct kino_IntMap *field_num_map));

KINO_METHOD("Kino_PostWriter_Destroy",
void
kino_PostWriter_destroy(kino_PostingsWriter *self));

KINO_END_CLASS

#endif /* H_KINO_POSTINGSWRITER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

