#ifndef H_KINO_POSTINGPOOL
#define H_KINO_POSTINGPOOL 1

#include "KinoSearch/Util/SortExRun.r"

struct kino_Schema;
struct kino_FieldSpec;
struct kino_Folder;
struct kino_SegInfo;
struct kino_InvIndex;
struct kino_Posting;
struct kino_RawPosting;
struct kino_TermStepper;
struct kino_InStream;
struct kino_TokenBatch;
struct kino_IntMap;

typedef struct kino_PostingPool kino_PostingPool;
typedef struct KINO_POSTINGPOOL_VTABLE KINO_POSTINGPOOL_VTABLE;

KINO_CLASS("KinoSearch::Index::PostingPool", "PostPool", 
    "KinoSearch::Util::SortExRun");

struct kino_PostingPool {
    KINO_POSTINGPOOL_VTABLE *_;
    KINO_SORTEXRUN_MEMBER_VARS;
    struct kino_Schema        *schema;
    struct kino_ByteBuf       *field_name;
    struct kino_FieldSpec     *fspec;
    struct kino_Posting       *posting;
    struct kino_TermStepper   *term_stepper;
    struct kino_MemoryPool    *mem_pool;
    struct kino_InStream      *lex_instream;
    struct kino_InStream      *post_instream;
    struct kino_IntMap        *doc_map;
    kino_Obj                 **scratch;
    chy_u32_t                  scratch_cap;
    chy_u64_t                  lex_start;
    chy_u64_t                  post_start;
    chy_u64_t                  lex_end;
    chy_u64_t                  post_end;
    chy_u32_t                  mem_thresh;
    chy_u32_t                  doc_base;
    chy_u32_t                  last_doc_num;
    chy_u32_t                  post_count;
    chy_bool_t                 flipped;
    chy_bool_t                 from_seg;
};

/* Constructor.
 */
kino_PostingPool*
kino_PostPool_new(struct kino_Schema *schema, 
                  const struct kino_ByteBuf *field_name,
                  struct kino_TermStepper *term_stepper,
                  struct kino_MemoryPool *mem_pool,
                  struct kino_IntMap *pre_sort_map);

/* Add a field's content, in the form of an inverted TokenBatch.
 */
void
kino_PostPool_add_batch(kino_PostingPool *self, 
                        struct kino_TokenBatch *batch, 
                        chy_i32_t doc_num, 
                        float doc_boost, 
                        float length_norm);
KINO_METHOD("Kino_PostPool_Add_Batch");


/* Add a RawPosting to the cache.
 */
void
kino_PostPool_add_posting(kino_PostingPool *self, 
                          struct kino_RawPosting *raw_posting);
KINO_METHOD("Kino_PostPool_Add_Posting");

/* Dedicated this PostingPool to read back from existing segment content.
 */
void
kino_PostPool_assign_seg(kino_PostingPool *self, 
                         struct kino_Folder *other_folder, 
                         struct kino_SegInfo *other_seg_info, 
                         chy_u32_t doc_base, 
                         struct kino_IntMap *doc_map);
KINO_METHOD("Kino_PostPool_Assign_Seg");

/* Iterate through postings currently in RAM.  Used when flushing cache to
 * disk.
 */
struct kino_RawPosting*
kino_PostPool_fetch_from_ram(kino_PostingPool *self);
KINO_METHOD("Kino_PostPool_Fetch_From_RAM");

/* Prepare to read back postings from disk.
 */
void
kino_PostPool_flip(kino_PostingPool *self, 
                   struct kino_InStream *lex_instream,
                   struct kino_InStream *post_instream,
                   chy_u32_t mem_thresh);
KINO_METHOD("Kino_PostPool_Flip");

/* Sort the current cache of RawPostings, if there's anything in it.
 */
void
kino_PostPool_sort_cache(kino_PostingPool *self);
KINO_METHOD("Kino_PostPool_Sort_Cache");

chy_u32_t
kino_PostPool_refill(kino_PostingPool *self);
KINO_METHOD("Kino_PostPool_Refill");

void
kino_PostPool_destroy(kino_PostingPool *self);
KINO_METHOD("Kino_PostPool_Destroy");

KINO_END_CLASS

#endif /* H_KINO_POSTINGPOOL */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

