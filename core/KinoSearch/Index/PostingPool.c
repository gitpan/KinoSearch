#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/PostingPool.h"
#include "KinoSearch/Analysis/Inversion.h"
#include "KinoSearch/Architecture.h"
#include "KinoSearch/Posting.h"
#include "KinoSearch/Posting/MatchPosting.h"
#include "KinoSearch/Posting/RawPosting.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/LexiconReader.h"
#include "KinoSearch/Index/TermStepper.h"
#include "KinoSearch/Index/PostingPoolQueue.h"
#include "KinoSearch/Index/PostingsReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Util/MemoryPool.h"
#include "KinoSearch/Util/I32Array.h"

PostingPool*
PostPool_init(PostingPool *self, Schema *schema, 
              const CharBuf *field, MemoryPool *mem_pool)
{
    /* Init. */
    SortExRun_init((SortExRun*)self);
    self->mem_thresh       = 0;
    self->doc_base         = 0;
    self->last_doc_id      = 0;
    self->doc_map          = NULL;
    self->post_count       = 0;
    self->scratch          = NULL;
    self->scratch_cap      = 0;
    self->lexicon          = NULL;
    self->plist            = NULL;

    /* Assign. */
    self->schema         = (Schema*)INCREF(schema);
    self->mem_pool       = (MemoryPool*)INCREF(mem_pool);
    self->field          = CB_Clone(field);

    return self;
}

void
PostPool_destroy(PostingPool *self)
{
    DECREF(self->schema);
    DECREF(self->mem_pool);
    DECREF(self->field);
    DECREF(self->doc_map);
    FREEMEM(self->scratch);
    
    /* Setting these to 0 causes SortExRun_Clear_Cache to avoid 
     * decrementing refcounts on cache elements -- which is 
     * important because they were all zapped when MemPool went
     * away.  */
    self->cache_max   = 0;
    self->cache_tick  = 0;

    SUPER_DESTROY(self, POSTINGPOOL);
}

static INLINE int
SI_compare_rawp(void *context, const void *va, const void *vb)
{
    RawPosting *const a = *(RawPosting**)va;
    RawPosting *const b = *(RawPosting**)vb;
    const size_t a_len = a->content_len;
    const size_t b_len = b->content_len;
    const size_t len = a_len < b_len? a_len : b_len;
    int comparison = memcmp(a->blob, b->blob, len);
    UNUSED_VAR(context);

    if (comparison == 0) {
        /* If a is a substring of b, it's less than b, so return a neg num. */
        comparison = a_len - b_len;

        /* Break ties by doc id. */
        if (comparison == 0) 
            comparison = a->doc_id - b->doc_id;
    }

    return comparison;
}

int
PostPool_compare_raw_postings(void *context, const void *va, const void *vb)
{
    return SI_compare_rawp(context, va, vb);
}

int
PostPool_compare(PostingPool *self, Obj **a, Obj **b)
{
    return SI_compare_rawp(self, a, b);
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
PostPool_sort_cache(PostingPool *self)
{
    if (self->cache_tick != 0)
        THROW(ERR, "Cant sort_cache when tick non-zero: %u32", self->cache_tick);
    if (self->scratch_cap < self->cache_cap) {
        self->scratch_cap = self->cache_cap;
        self->scratch = REALLOCATE(self->scratch, self->scratch_cap, Obj*);
    }
    if (self->cache_max != 0) {
        Sort_compare_t sort_func
            = (Sort_compare_t)METHOD(POSTINGPOOL, PostPool, Compare);
        Sort_mergesort(self->cache, self->scratch, self->cache_max,
            sizeof(Obj*), sort_func, self);
    }
}

RawPosting*
PostPool_fetch_from_ram(PostingPool *self)
{
    if (self->cache_tick == self->cache_max)
        return NULL;
    return (RawPosting*)self->cache[ self->cache_tick++ ];
}


void
PostPool_shrink(PostingPool *self)
{
    /* Make sure cache is empty. */
    if (self->cache_max - self->cache_tick > 0) {
        THROW(ERR, "Cache contains %u32 items, so can't shrink",
            self->cache_max - self->cache_tick);
    } 
    self->cache_tick  = 0; 
    self->cache_max   = 0;
    self->cache_cap   = 0;
    self->scratch_cap = 0;
    FREEMEM(self->cache);
    FREEMEM(self->scratch);
    self->cache       = NULL;
    self->scratch     = NULL;
}


u32_t
PostPool_refill(PostingPool *self)
{
    Lexicon *const     lexicon     = self->lexicon;
    PostingList *const plist       = self->plist;
    I32Array    *const doc_map     = self->doc_map;
    const u32_t        mem_thresh  = self->mem_thresh;
    const i32_t        doc_base    = self->doc_base;
    u32_t              num_elems   = 0; /* number of items recovered */
    MemoryPool        *mem_pool;
    CharBuf           *term_text   = NULL;

    if (self->lexicon == NULL) { return 0; }
    else { term_text = (CharBuf*)Lex_Get_Term(lexicon); }

    /* Make sure cache is empty. */
    if (self->cache_max - self->cache_tick > 0) {
        THROW(ERR, "Refill called but cache contains %u32 items",
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
            if (Lex_Next(lexicon)) {
                self->post_count = Lex_Doc_Freq(lexicon);
                term_text = (CharBuf*)Lex_Get_Term(lexicon);
                if (term_text && !OBJ_IS_A(term_text, CHARBUF)) {
                    THROW(ERR, "Only CharBuf terms are supported for now");
                }
                {
                    Posting *posting = PList_Get_Posting(plist);
                    Post_Set_Doc_ID(posting, doc_base);
                    self->last_doc_id = doc_base;
                }
            }
            /* Bail if we've read everything in this run. */
            else {
                break;
            }
        }

        /* Bail if we've hit the ceiling for this run's cache. */
        if (mem_pool->consumed >= mem_thresh && num_elems > 0)
            break;

        /* Read a posting from the input stream. */
        raw_posting = PList_Read_Raw(plist, self->last_doc_id, term_text, 
            mem_pool);
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

/***************************************************************************/

FreshPostingPool*
FreshPostPool_new(Schema *schema, const CharBuf *field, MemoryPool *mem_pool)
{
    FreshPostingPool *self 
        = (FreshPostingPool*)VTable_Make_Obj(FRESHPOSTINGPOOL);
    return FreshPostPool_init(self, schema, field, mem_pool);
}

FreshPostingPool*
FreshPostPool_init(FreshPostingPool *self, Schema *schema, 
                   const CharBuf *field, MemoryPool *mem_pool)
{
    /* Init. */
    PostPool_init((PostingPool*)self, schema, field, mem_pool);
    self->lex_start        = I64_MAX;
    self->post_start       = I64_MAX;
    self->lex_end          = 0;
    self->post_end         = 0;
    self->flipped          = false;

    /* Derive. */
    self->posting = Schema_Fetch_Posting(schema, field);
    self->posting = (Posting*)Post_Clone(self->posting);
    self->type    = (FieldType*)INCREF(Schema_Fetch_Type(schema, field));

    return self;
}

void
FreshPostPool_destroy(FreshPostingPool *self)
{
    DECREF(self->posting);
    DECREF(self->type);
    SUPER_DESTROY(self, FRESHPOSTINGPOOL);
}

void
FreshPostPool_set_lex_start(FreshPostingPool *self, i64_t lex_start)
    { self->lex_start = lex_start; }
void
FreshPostPool_set_lex_end(FreshPostingPool *self, i64_t lex_end)
    { self->lex_end = lex_end; }
void
FreshPostPool_set_post_start(FreshPostingPool *self, i64_t post_start)
    { self->post_start = post_start; }
void
FreshPostPool_set_post_end(FreshPostingPool *self, i64_t post_end)
    { self->post_end = post_end; }

void
FreshPostPool_add_inversion(FreshPostingPool *self, Inversion *inversion, 
                            i32_t doc_id, float doc_boost, float length_norm)
{
    Post_Add_Inversion_To_Pool(self->posting, (PostingPool*)self, inversion, 
        self->type, doc_id, doc_boost, length_norm);
}

void
FreshPostPool_flip(FreshPostingPool *self, InStream *lex_instream,
                   InStream *post_instream, u32_t mem_thresh)
{
    if (self->flipped) { THROW(ERR, "Can't call Flip twice"); }
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

    /* Bail if never flushed. */
    if (self->lex_end == 0) { return; }

    /* Get a Lexicon and a PostingList. */
    self->lexicon = (Lexicon*)RawLex_new(self->schema, self->field, 
        InStream_Clone(lex_instream), self->lex_start, self->lex_end);
    self->plist = (PostingList*)RawPList_new(self->schema, self->field, 
        InStream_Clone(post_instream), self->post_start, self->post_end);
}

/***************************************************************************/

MergePostingPool*
MergePostPool_new(Schema *schema, const CharBuf *field, MemoryPool *mem_pool,
                  SegReader *reader, I32Array *doc_map, i32_t doc_base)
{
    MergePostingPool *self 
        = (MergePostingPool*)VTable_Make_Obj(MERGEPOSTINGPOOL);
    return MergePostPool_init(self, schema, field, mem_pool, reader, doc_map,
        doc_base);
}

MergePostingPool*
MergePostPool_init(MergePostingPool *self, Schema *schema, 
                   const CharBuf *field, MemoryPool *mem_pool,
                   SegReader *reader, I32Array *doc_map, i32_t doc_base)
{
    LexiconReader *lex_reader 
        = (LexiconReader*)SegReader_Fetch(reader, LEXICONREADER->name);
    PostingsReader *plist_reader 
        = (PostingsReader*)SegReader_Fetch(reader, POSTINGSREADER->name);

    /* Init. */
    PostPool_init((PostingPool*)self, schema, field, mem_pool);

    /* Assign. */
    self->doc_base = doc_base;
    self->doc_map  = doc_map ? (I32Array*)INCREF(doc_map) : NULL;

    /* Derive. */
    self->lexicon = lex_reader 
        ? LexReader_Lexicon(lex_reader, field, NULL) 
        : NULL;
    self->plist = plist_reader 
        ? PostReader_Posting_List(plist_reader, field, NULL) 
        : NULL;

    return self;
}

void
MergePostPool_destroy(MergePostingPool *self)
{
    DECREF(self->plist);
    DECREF(self->lexicon);
    SUPER_DESTROY(self, MERGEPOSTINGPOOL);
}

void
MergePostPool_set_mem_thresh(MergePostingPool *self, u32_t mem_thresh)
{
    self->mem_thresh = mem_thresh;
}

/***************************************************************************/

RawLexicon*
RawLex_new(Schema *schema, const CharBuf *field, InStream *instream, 
           i64_t start, i64_t end)
{
    RawLexicon *self = (RawLexicon*)VTable_Make_Obj(RAWLEXICON);
    return RawLex_init(self, schema, field, instream, start, end);
}

RawLexicon*
RawLex_init(RawLexicon *self, Schema *schema, const CharBuf *field,
            InStream *instream, i64_t start, i64_t end)
{
    FieldType *type = Schema_Fetch_Type(schema, field);
    Lex_init((Lexicon*)self);
    
    /* Assign */
    self->start = start;
    self->end   = end;
    self->instream = (InStream*)INCREF(instream);

    /* Get ready to begin. */
    InStream_Seek(self->instream, self->start);

    /* Get steppers. */
    self->term_stepper  = FType_Make_Term_Stepper(type);
    self->tinfo_stepper = (TermStepper*)MatchTInfoStepper_new(schema);

    return self;
}

void
RawLex_destroy(RawLexicon *self)
{
    DECREF(self->instream);
    DECREF(self->term_stepper);
    DECREF(self->tinfo_stepper);
    SUPER_DESTROY(self, RAWLEXICON);
}

bool_t
RawLex_next(RawLexicon *self)
{
    if (InStream_Tell(self->instream) >= self->end) { return false; }
    TermStepper_Read_Delta(self->term_stepper, self->instream);
    TermStepper_Read_Delta(self->tinfo_stepper, self->instream);
    return true;
}

Obj*
RawLex_get_term(RawLexicon *self)
{
    return TermStepper_Get_Value(self->term_stepper);
}

i32_t
RawLex_doc_freq(RawLexicon *self)
{
    TermInfo *tinfo = (TermInfo*)TermStepper_Get_Value(self->tinfo_stepper);
    return tinfo ? tinfo->doc_freq : 0;
}

/***************************************************************************/

RawPostingList*
RawPList_new(Schema *schema, const CharBuf *field, InStream *instream, 
           i64_t start, i64_t end)
{
    RawPostingList *self = (RawPostingList*)VTable_Make_Obj(RAWPOSTINGLIST);
    return RawPList_init(self, schema, field, instream, start, end);
}

RawPostingList*
RawPList_init(RawPostingList *self, Schema *schema, const CharBuf *field,
            InStream *instream, i64_t start, i64_t end)
{
    Posting *posting = Schema_Fetch_Posting(schema, field);
    PList_init((PostingList*)self);
    self->start    = start;
    self->end      = end;
    self->instream = (InStream*)INCREF(instream);
    self->posting  = (Posting*)Post_Clone(posting);
    InStream_Seek(self->instream, self->start);
    return self;
}

void
RawPList_destroy(RawPostingList *self)
{
    DECREF(self->instream);
    DECREF(self->posting);
    SUPER_DESTROY(self, RAWPOSTINGLIST);
}

Posting*
RawPList_get_posting(RawPostingList *self)
{
    return self->posting;
}

RawPosting*
RawPList_read_raw(RawPostingList *self, i32_t last_doc_id, CharBuf *term_text,
                  MemoryPool *mem_pool)
{
    return Post_Read_Raw(self->posting, self->instream, 
        last_doc_id, term_text, mem_pool);
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

