#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_POSTINGPOOL_VTABLE
#include "KinoSearch/Index/PostingPool.r"

#include "KinoSearch/Analysis/TokenBatch.r"
#include "KinoSearch/Posting.r"
#include "KinoSearch/Posting/RawPosting.r"
#include "KinoSearch/Schema.r"
#include "KinoSearch/Schema/FieldSpec.r"
#include "KinoSearch/Index/PostingPoolQueue.r"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Index/TermStepper.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Util/MemoryPool.r"
#include "KinoSearch/Util/IntMap.r"

/* Constructor.
 */
PostingPool*
PostPool_new(Schema *schema, const ByteBuf *field_name, 
             TermStepper *term_stepper, MemoryPool *mem_pool, 
             IntMap *pre_sort_remap)
{
    MSort_compare_t compare = pre_sort_remap == NULL 
        ? PostPoolQ_compare_rawp
        : PostPoolQ_compare_rawp_for_pre_sort;
    CREATE(self, PostingPool, POSTINGPOOL);

    /* init */
    kino_SortExRun_init_base((SortExRun*)self, compare);
    self->lex_instream     = NULL;
    self->post_instream    = NULL;
    self->lex_start        = U64_MAX;
    self->post_start       = U64_MAX;
    self->lex_end          = 0;
    self->post_end         = 0;
    self->flipped          = false;
    self->from_seg         = false;
    self->mem_thresh       = 0;
    self->doc_base         = 0;
    self->last_doc_num     = 0;
    self->doc_map          = NULL;
    self->post_count       = 0;
    self->scratch          = NULL;
    self->scratch_cap      = 0;

    /* assign */
    REFCOUNT_INC(term_stepper);
    REFCOUNT_INC(schema);
    REFCOUNT_INC(mem_pool);
    self->schema         = schema;
    self->mem_pool       = mem_pool;
    self->term_stepper   = term_stepper;
    self->field_name     = BB_CLONE(field_name);
    if (pre_sort_remap != NULL) {
        REFCOUNT_INC(pre_sort_remap);
        self->context = (Obj*)pre_sort_remap;
    }

    /* derive */
    self->posting = Schema_Fetch_Posting(schema, field_name);
    self->fspec   = Schema_Fetch_FSpec(schema, field_name);
    REFCOUNT_INC(self->fspec);

    return self;
}

void
PostPool_destroy(PostingPool *self)
{
    REFCOUNT_DEC(self->schema);
    REFCOUNT_DEC(self->mem_pool);
    REFCOUNT_DEC(self->field_name);
    REFCOUNT_DEC(self->lex_instream);
    REFCOUNT_DEC(self->post_instream);
    REFCOUNT_DEC(self->term_stepper);
    REFCOUNT_DEC(self->posting);
    REFCOUNT_DEC(self->fspec);
    REFCOUNT_DEC(self->doc_map);
    REFCOUNT_DEC(self->context);
    free(self->cache);
    free(self->scratch);
    free(self);

}

void
PostPool_add_batch(PostingPool *self, TokenBatch *batch, 
                   i32_t doc_num, float doc_boost, 
                   float length_norm)
{
    Post_Add_Batch_To_Pool(self->posting, self, batch, self->fspec, 
        doc_num, doc_boost, length_norm);
}

void
PostPool_add_posting(PostingPool *self, RawPosting *raw_posting)
{
    if (self->cache_max >= self->cache_cap)
        PostPool_Grow_Cache(self, self->cache_max + 1);

    /* add element to cache */
    self->cache[ self->cache_max++ ] = (Obj*)raw_posting;
}

void
PostPool_assign_seg(PostingPool *self, Folder *other_folder, 
                    SegInfo *other_seg_info, u32_t doc_base, IntMap *doc_map)
{
    ByteBuf *filename  = BB_CLONE(other_seg_info->seg_name);
    i32_t    field_num = SegInfo_Field_Num(other_seg_info, self->field_name);

    /* dedicate pool to this task alone */
    if (self->from_seg || self->cache_max > 0 || self->lex_end != 0)
        CONFESS("Can't Assign_Segment to PostingPool with other content");
    self->from_seg = true;

    /* prepare to read from existing files */
    BB_Cat_Str(filename, ".lex", 4);
    BB_Cat_I64(filename, field_num);
    if ( Folder_File_Exists(other_folder, filename) ) {
        /* open terms file */
        self->lex_instream = Folder_Open_InStream(other_folder, filename);
        self->lex_end = InStream_SLength(self->lex_instream);

        /* open postings file */
        BB_Copy_BB(filename, other_seg_info->seg_name);
        BB_Cat_Str(filename, ".p", 2);
        BB_Cat_I64(filename, field_num);
        self->post_instream = Folder_Open_InStream(other_folder, filename);
        self->post_end = InStream_SLength(self->post_instream);

        /* assign doc base and doc map */
        self->doc_base = doc_base;
        REFCOUNT_INC(doc_map);
        self->doc_map  = doc_map;
    }
    else {
        /* this posting pool will be empty */
    }

    /* clean up */
    REFCOUNT_DEC(filename);
}

void
PostPool_sort_cache(PostingPool *self)
{
    if (self->cache_tick != 0)
        CONFESS("Cant sort_cache when tick non-zero: %u", self->cache_tick);
    if (self->scratch_cap < self->cache_cap) {
        self->scratch_cap = self->cache_cap;
        self->scratch = REALLOCATE(self->scratch, self->scratch_cap, Obj*);
    }
    if (self->cache_max != 0)
        MSort_mergesort(self->cache, self->scratch, self->cache_max,
            sizeof(Obj*), self->compare, self->context);
}

RawPosting*
PostPool_fetch_from_ram(PostingPool *self)
{
    if (self->cache_tick == self->cache_max)
        return NULL;
    return (RawPosting*)self->cache[ self->cache_tick++ ];
}

void
PostPool_flip(PostingPool *self, InStream *lex_instream,
              InStream *post_instream, u32_t mem_thresh)
{
    if (self->flipped)
        CONFESS("Can't call Flip twice");
    self->flipped = true;

    /* assign memory threshold */
    self->mem_thresh = mem_thresh;

    /* reset cache if all elems have been cleared out */
    if (self->cache_tick == self->cache_max) {
        self->cache_tick = 0;
        self->cache_max  = 0;
    }

    /* sort RawPostings in cache, if any */
    PostPool_Sort_Cache(self);

    /* bail if assigned a segment or if never flushed */
    if (self->from_seg || self->lex_end == 0)
        return;

    /* clone streams */
    self->lex_instream   = (InStream*)InStream_Clone(lex_instream);
    self->post_instream  = (InStream*)InStream_Clone(post_instream);
    InStream_SSeek(self->lex_instream,   self->lex_start);
    InStream_SSeek(self->post_instream, self->post_start);
}

u32_t
PostPool_refill(PostingPool *self)
{
    TermStepper *const term_stepper    = self->term_stepper;
    Posting     *const main_posting    = self->posting;
    InStream    *const lex_instream    = self->lex_instream;
    InStream    *const post_instream   = self->post_instream;
    IntMap      *const doc_map         = self->doc_map;
    const u32_t        mem_thresh      = self->mem_thresh;
    const u32_t        doc_base        = self->doc_base;
    const u64_t        lex_end         = self->lex_end;
    u32_t              num_elems       = 0; /* number of items recovered */
    ByteBuf           *term_text       = term_stepper->term == NULL 
                                            ? NULL 
                                            : term_stepper->term->text;
    MemoryPool        *mem_pool;

    if (!self->flipped)
        CONFESS("Can't call Refill before Flip");

    if (lex_instream == NULL)
        return 0;

    /* make sure cache is empty */
    if (self->cache_max - self->cache_tick > 0) {
        CONFESS("Refill called but cache contains %u items",
            self->cache_max - self->cache_tick);
    }
    self->cache_max  = 0;
    self->cache_tick = 0;

    /* ditch old MemoryPool and get another */
    REFCOUNT_DEC(self->mem_pool);
    self->mem_pool = MemPool_new(self->mem_thresh + 4096);
    mem_pool       = self->mem_pool;

    while (1) {
        RawPosting *raw_posting;

        if (self->post_count == 0) {
            /* read a term */
            if (InStream_STell(lex_instream) < lex_end) {
                TermStepper_Read_Record(term_stepper, lex_instream);
                self->post_count = term_stepper->tinfo->doc_freq;
                term_text = term_stepper->term->text;
                Post_Reset(main_posting, doc_base);
                self->last_doc_num = doc_base;
            }
            /* bail if we've read everything in this run */
            else {
                /* make sure we haven't read too much */
                if (InStream_STell(lex_instream) > lex_end) {
                    long pos = (long)InStream_STell(lex_instream);
                    CONFESS("tl read error: %ld %ld", pos, (long)lex_end);
                }
                else if (InStream_STell(post_instream) != self->post_end) {
                    long pos = (long)InStream_STell(post_instream);
                    CONFESS("post read error: %ld %ld", pos, (long)lex_end);
                }
                /* we're ok. */
                break;
            }
        }

        /* bail if we've hit the ceiling for this run's cache */
        if (mem_pool->consumed >= mem_thresh && num_elems > 0)
            break;

        /* read a posting from the input stream */
        raw_posting = Post_Read_Raw(main_posting, post_instream, 
            self->last_doc_num, term_text, mem_pool);
        self->post_count--;

        /* skip deletions */
        if (doc_map != NULL) {
            const i32_t remapped = IntMap_Get(doc_map, 
                raw_posting->doc_num - doc_base);
            if (remapped == -1)
                continue;
            raw_posting->doc_num = remapped;
        }

        /* add to the run's cache */
        if (num_elems == self->cache_cap) {
            PostPool_Grow_Cache(self, num_elems);
        }
        self->cache[ num_elems ] = (Obj*)raw_posting;
        self->last_doc_num = raw_posting->doc_num;
        num_elems++;
    }

    /* reset the cache array position and length; remember file pos */
    self->cache_max   = num_elems;
    self->cache_tick  = 0;

    return num_elems;
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

