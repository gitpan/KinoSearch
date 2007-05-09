#ifndef H_KINO_POSTINGSWRITER
#define H_KINO_POSTINGSWRITER 1

#include "KinoSearch/Util/Obj.r"

struct kino_TokenBatch;
struct kino_FieldSpec;
struct kino_InvIndex;
struct kino_Folder;
struct kino_LexWriter;
struct kino_SegLexicon;
struct kino_SegPostingList;
struct kino_IntMap;
struct kino_SegInfo;
struct kino_MemoryPool;

typedef struct kino_PostingsWriter kino_PostingsWriter;
typedef struct KINO_POSTINGSWRITER_VTABLE KINO_POSTINGSWRITER_VTABLE;

KINO_FINAL_CLASS("KinoSearch::Index::PostingsWriter", "PostWriter", 
    "KinoSearch::Util::Obj");

struct kino_PostingsWriter {
    KINO_POSTINGSWRITER_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_InvIndex        *invindex;
    struct kino_SegInfo         *seg_info;
    struct kino_LexWriter       *lex_writer;
    struct kino_PreSorter       *pre_sorter;
    struct kino_VArray          *post_pools;
    struct kino_MemoryPool      *mem_pool;
    struct kino_SkipStepper     *skip_stepper;
    struct kino_ByteBuf         *lex_tempname;
    struct kino_ByteBuf         *post_tempname;
    struct kino_OutStream       *lex_outstream;
    struct kino_OutStream       *post_outstream;
    struct kino_OutStream       *skip_stream;
    struct kino_InStream        *lex_instream;
    struct kino_InStream        *post_instream;
    chy_u32_t                    mem_thresh;
};

/* Constructor.
 */
kino_PostingsWriter*
kino_PostWriter_new(struct kino_InvIndex *invindex, 
                    struct kino_SegInfo *seg_info, 
                    struct kino_LexWriter *lex_writer,
                    struct kino_PreSorter *pre_sorter,
                    chy_u32_t mem_thresh);

/* Add a field's content, in the form of an inverted TokenBatch.
 */
void
kino_PostWriter_add_batch(kino_PostingsWriter *self, 
                          struct kino_TokenBatch *batch, 
                          const struct kino_ByteBuf *field_name,
                          chy_i32_t doc_num, 
                          float doc_boost, 
                          float length_norm);
KINO_METHOD("Kino_PostWriter_Add_Batch");

/* Add terms and postings for a field from an existing segment.  The segment
 * may belong to the same invindex or to a different invindex.
 */
void
kino_PostWriter_add_seg_data(kino_PostingsWriter *self, 
                            struct kino_Folder  *other_folder,
                            struct kino_SegInfo *other_seg_info,
                            struct kino_IntMap  *doc_map);
KINO_METHOD("Kino_PostWriter_Add_Seg_Data");

/* Write all postings files.  Write skipdata.  Hand off data to LexWriter
 * for the generating the term dictionaries.  Record metadata.
 */
void
kino_PostWriter_finish(kino_PostingsWriter *self);
KINO_METHOD("Kino_PostWriter_Finish");

void
kino_PostWriter_destroy(kino_PostingsWriter *self);
KINO_METHOD("Kino_PostWriter_Destroy");

KINO_END_CLASS

#endif /* H_KINO_POSTINGSWRITER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

