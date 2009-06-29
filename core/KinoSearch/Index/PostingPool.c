#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/PostingPool.h"
#include "KinoSearch/Analysis/Inversion.h"
#include "KinoSearch/Architecture.h"
#include "KinoSearch/Posting.h"
#include "KinoSearch/Posting/RawPosting.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/LexStepper.h"
#include "KinoSearch/Index/PostingPoolQueue.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Util/MemoryPool.h"
#include "KinoSearch/Util/I32Array.h"

/* Constructor.
 */
PostingPool*
PostPool_new(Schema *schema, const CharBuf *field, MemoryPool *mem_pool)
{
    PostingPool *self = (PostingPool*)VTable_Make_Obj(&POSTINGPOOL);
    return PostPool_init(self, schema, field, mem_pool);
}

PostingPool*
PostPool_init(PostingPool *self, Schema *schema, 
              const CharBuf *field, MemoryPool *mem_pool)
{
    Architecture *arch = Schema_Get_Architecture(schema);

    /* Init. */
    SortExRun_init((SortExRun*)self);
    self->lex_instream     = NULL;
    self->post_instream    = NULL;
    self->lex_start        = I64_MAX;
    self->post_start       = I64_MAX;
    self->lex_end          = 0;
    self->post_end         = 0;
    self->flipped          = false;
    self->from_seg         = false;
    self->mem_thresh       = 0;
    self->doc_base         = 0;
    self->last_doc_id      = 0;
    self->doc_map          = NULL;
    self->post_count       = 0;
    self->scratch          = NULL;
    self->scratch_cap      = 0;
    self->lex_stepper = LexStepper_new(field, Arch_Skip_Interval(arch));

    /* Assign. */
    self->schema         = (Schema*)INCREF(schema);
    self->mem_pool       = (MemoryPool*)INCREF(mem_pool);
    self->field          = CB_Clone(field);

    /* Derive. */
    self->posting = Schema_Fetch_Posting(schema, field);
    self->posting = (Posting*)Post_Clone(self->posting);
    self->type    = (FieldType*)INCREF(Schema_Fetch_Type(schema, field));
    self->compare = PostPoolQ_compare_rawp;

    return self;
}

void
PostPool_destroy(PostingPool *self)
{
    DECREF(self->schema);
    DECREF(self->mem_pool);
    DECREF(self->field);
    DECREF(self->lex_instream);
    DECREF(self->post_instream);
    DECREF(self->lex_stepper);
    DECREF(self->posting);
    DECREF(self->type);
    DECREF(self->doc_map);
    free(self->scratch);
    
    /* Setting these to 0 causes SortExRun_Clear_Cache to avoid 
     * decrementing refcounts on cache elements -- which is 
     * important because they were all zapped when MemPool went
     * away.  */
    self->cache_max   = 0;
    self->cache_tick  = 0;

    SUPER_DESTROY(self, POSTINGPOOL);
}

int
PostPool_compare(PostingPool *self, Obj **a, Obj **b)
{
    return self->compare(self, a, b);
}

void
PostPool_add_elem(PostingPool *self, Obj *elem)
{
    if (self->cache_max >= self->cache_cap)
        PostPool_Grow_Cache(self, self->cache_max + 1);

    /* Add element to cache. */
    self->cache[ self->cache_max++ ] = elem;
}

void
PostPool_add_inversion(PostingPool *self, Inversion *inversion, 
                   i32_t doc_id, float doc_boost, 
                   float length_norm)
{
    Post_Add_Inversion_To_Pool(self->posting, self, inversion, self->type, 
        doc_id, doc_boost, length_norm);
}

void
PostPool_assign_seg(PostingPool *self, Folder *other_folder, 
                    Segment *other_segment, i32_t doc_base, I32Array *doc_map)
{
    i32_t    field_num = Seg_Field_Num(other_segment, self->field);
    CharBuf *other_seg_name = Seg_Get_Name(other_segment);
    CharBuf *lex_file 
        = CB_newf("%o/lexicon-%i32.dat", other_seg_name, field_num);

    /* Dedicate pool to this task alone. */
    if (self->from_seg || self->cache_max > 0 || self->lex_end != 0)
        THROW("Can't Assign_Segment to PostingPool with other content");
    self->from_seg = true;

    /* Prepare to read from existing files. */
    if (Folder_Exists(other_folder, lex_file)) {
        CharBuf *post_file
            = CB_newf("%o/postings-%i32.dat", other_seg_name, field_num);

        /* Open lexicon and postings files. */
        self->lex_instream  = Folder_Open_In(other_folder, lex_file);
        self->post_instream = Folder_Open_In(other_folder, post_file);
        if (!self->lex_instream)  { THROW("Can't open %o", lex_file); }
        if (!self->post_instream) { THROW("Can't open %o", post_file); }
        self->lex_end       = InStream_Length(self->lex_instream);
        self->post_end      = InStream_Length(self->post_instream);

        /* Assign doc base and doc map. */
        self->doc_base = doc_base;
        self->doc_map  = doc_map ? (I32Array*)INCREF(doc_map) : NULL;

        DECREF(post_file);
    }
    else {
        /* This posting pool will be empty. */
    }

    /* Clean up. */
    DECREF(lex_file);
}

void
PostPool_sort_cache(PostingPool *self)
{
    if (self->cache_tick != 0)
        THROW("Cant sort_cache when tick non-zero: %u32", self->cache_tick);
    if (self->scratch_cap < self->cache_cap) {
        self->scratch_cap = self->cache_cap;
        self->scratch = REALLOCATE(self->scratch, self->scratch_cap, Obj*);
    }
    if (self->cache_max != 0)
        Sort_mergesort(self->cache, self->scratch, self->cache_max,
            sizeof(Obj*), self->compare, self);
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
        THROW("Can't call Flip twice");
    self->flipped = true;

    /* Assign memory threshold. */
    self->mem_thresh = mem_thresh;

    /* Reset cache if all elems have been cleared out. */
    if (self->cache_tick == self->cache_max) {
        self->cache_tick = 0;
        self->cache_max  = 0;
    }

    /* Sort RawPostings in cache, if any. */
    PostPool_Sort_Cache(self);

    /* Bail if assigned a segment or if never flushed. */
    if (self->from_seg || self->lex_end == 0)
        return;

    /* Clone streams. */
    self->lex_instream   = (InStream*)InStream_Clone(lex_instream);
    self->post_instream  = (InStream*)InStream_Clone(post_instream);
    InStream_Seek(self->lex_instream,   self->lex_start);
    InStream_Seek(self->post_instream, self->post_start);
}

void
PostPool_shrink(PostingPool *self)
{
    /* Make sure cache is empty. */
    if (self->cache_max - self->cache_tick > 0) {
        THROW("Cache contains %u32 items, so can't shrink",
            self->cache_max - self->cache_tick);
    } 
    self->cache_tick  = 0; 
    self->cache_max   = 0;
    self->cache_cap   = 0;
    self->scratch_cap = 0;
    free(self->cache);
    free(self->scratch);
    self->cache       = NULL;
    self->scratch     = NULL;
}

u32_t
PostPool_refill(PostingPool *self)
{
    LexStepper  *const lex_stepper     = self->lex_stepper;
    Posting     *const main_posting    = self->posting;
    InStream    *const lex_instream    = self->lex_instream;
    InStream    *const post_instream   = self->post_instream;
    I32Array    *const doc_map         = self->doc_map;
    const u32_t        mem_thresh      = self->mem_thresh;
    const i32_t        doc_base        = self->doc_base;
    const i64_t        lex_end         = self->lex_end;
    u32_t              num_elems       = 0; /* number of items recovered */
    CharBuf           *term_text       = lex_stepper->value == NULL 
                                            ? NULL 
                                            : (CharBuf*)lex_stepper->value;
    MemoryPool        *mem_pool;

    if (!self->flipped)
        THROW("Can't call Refill before Flip");

    if (lex_instream == NULL)
        return 0;

    /* Make sure cache is empty. */
    if (self->cache_max - self->cache_tick > 0) {
        THROW("Refill called but cache contains %u32 items",
            self->cache_max - self->cache_tick);
    }
    self->cache_max  = 0;
    self->cache_tick = 0;

    /* Ditch old MemoryPool and get another. */
    DECREF(self->mem_pool);
    self->mem_pool = MemPool_new(self->mem_thresh + 4096);
    mem_pool       = self->mem_pool;

    while (1) {
        RawPosting *raw_posting;

        if (self->post_count == 0) {
            /* Read a term. */
            if (InStream_Tell(lex_instream) < lex_end) {
                LexStepper_Read_Record(lex_stepper, lex_instream);
                self->post_count = lex_stepper->tinfo->doc_freq;
                term_text = (CharBuf*)lex_stepper->value;
                Post_Reset(main_posting, doc_base);
                self->last_doc_id = doc_base;
            }
            /* Bail if we've read everything in this run. */
            else {
                /* Make sure we haven't read too much. */
                if (InStream_Tell(lex_instream) > lex_end) {
                    i64_t pos = InStream_Tell(lex_instream);
                    THROW("tl read error: %i64 %i64", pos, lex_end);
                }
                else if (InStream_Tell(post_instream) != self->post_end) {
                    i64_t pos = InStream_Tell(lex_instream);
                    THROW("post read error: %i64 %i64", pos, lex_end);
                }
                /* We're ok. */
                break;
            }
        }

        /* Bail if we've hit the ceiling for this run's cache. */
        if (mem_pool->consumed >= mem_thresh && num_elems > 0)
            break;

        /* Read a posting from the input stream. */
        raw_posting = Post_Read_Raw(main_posting, post_instream, 
            self->last_doc_id, term_text, mem_pool);
        self->last_doc_id = raw_posting->doc_id;
        self->post_count--;

        /* Skip deletions. */
        if (doc_map != NULL) {
            const i32_t remapped = I32Arr_Get(doc_map, 
                raw_posting->doc_id - doc_base);
            if ( !remapped )
                continue;
            raw_posting->doc_id = remapped;
        }

        /* Add to the run's cache. */
        if (num_elems == self->cache_cap) {
            PostPool_Grow_Cache(self, num_elems);
        }
        self->cache[ num_elems ] = (Obj*)raw_posting;
        num_elems++;
    }

    /* Reset the cache array position and length; remember file pos. */
    self->cache_max   = num_elems;
    self->cache_tick  = 0;

    return num_elems;
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

