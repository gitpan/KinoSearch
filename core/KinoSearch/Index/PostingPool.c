#define C_KINO_POSTINGPOOL
#define C_KINO_RAWPOSTING
#define C_KINO_MEMORYPOOL
#define C_KINO_TERMINFO
#define C_KINO_SKIPSTEPPER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/PostingPool.h"
#include "KinoSearch/Analysis/Inversion.h"
#include "KinoSearch/Plan/Architecture.h"
#include "KinoSearch/Posting.h"
#include "KinoSearch/Posting/RawPosting.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/LexiconReader.h"
#include "KinoSearch/Index/LexiconWriter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/PostingListReader.h"
#include "KinoSearch/Index/RawLexicon.h"
#include "KinoSearch/Index/RawPostingList.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Index/SkipStepper.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Index/TermStepper.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/MemoryPool.h"

/** Prepare to read back postings from disk.
 */
static void
S_fresh_flip(PostingPool *self, InStream *lex_temp_in, 
             InStream *post_temp_in);

typedef Obj*
(*kino_PostPool_fetch_t)(PostingPool *self);
#define PostPool_fetch_t kino_PostPool_fetch_t

/* Like Fetch(), but does not access external storage. 
 */
static Obj*
S_fetch_from_ram(PostingPool *self);

/* Main loop. */
static void
S_write_terms_and_postings(PostingPool *self, PostingStreamer *streamer,
                           PostPool_fetch_t fetch, OutStream *skip_stream);

PostingPool*
PostPool_new(Schema *schema, Snapshot *snapshot, Segment *segment, 
             PolyReader *polyreader,  const CharBuf *field, 
             LexiconWriter *lex_writer, MemoryPool *mem_pool, 
             OutStream *lex_temp_out, OutStream *post_temp_out,
             OutStream *skip_out)
{
    PostingPool *self = (PostingPool*)VTable_Make_Obj(POSTINGPOOL);
    return PostPool_init(self, schema, snapshot, segment, polyreader, field, 
        lex_writer, mem_pool, lex_temp_out, post_temp_out, skip_out);
}

PostingPool*
PostPool_init(PostingPool *self, Schema *schema, Snapshot *snapshot, 
              Segment *segment, PolyReader *polyreader, const CharBuf *field, 
              LexiconWriter *lex_writer, MemoryPool *mem_pool, 
              OutStream *lex_temp_out, OutStream *post_temp_out, 
              OutStream *skip_out)
{
    /* Init. */
    SortEx_init((SortExternal*)self, 0);
    self->doc_base         = 0;
    self->last_doc_id      = 0;
    self->doc_map          = NULL;
    self->post_count       = 0;
    self->lexicon          = NULL;
    self->plist            = NULL;
    self->lex_temp_in      = NULL;
    self->post_temp_in     = NULL;
    self->lex_start        = I64_MAX;
    self->post_start       = I64_MAX;
    self->lex_end          = 0;
    self->post_end         = 0;
    self->skip_stepper     = SkipStepper_new();

    /* Assign. */
    self->schema         = (Schema*)INCREF(schema);
    self->snapshot       = (Snapshot*)INCREF(snapshot);
    self->segment        = (Segment*)INCREF(segment);
    self->polyreader     = (PolyReader*)INCREF(polyreader);
    self->lex_writer     = (LexiconWriter*)INCREF(lex_writer);
    self->mem_pool       = (MemoryPool*)INCREF(mem_pool);
    self->field          = CB_Clone(field);
    self->lex_temp_out   = (OutStream*)INCREF(lex_temp_out);
    self->post_temp_out  = (OutStream*)INCREF(post_temp_out);
    self->skip_out       = (OutStream*)INCREF(skip_out);

    /* Derive. */
    Posting *posting = Schema_Fetch_Posting(schema, field);
    self->posting   = (Posting*)Post_Clone(posting);
    self->type      = (FieldType*)INCREF(Schema_Fetch_Type(schema, field));
    self->field_num = Seg_Field_Num(segment, field);

    return self;
}

void
PostPool_destroy(PostingPool *self)
{
    DECREF(self->schema);
    DECREF(self->snapshot);
    DECREF(self->segment);
    DECREF(self->polyreader);
    DECREF(self->lex_writer);
    DECREF(self->mem_pool);
    DECREF(self->field);
    DECREF(self->doc_map);
    DECREF(self->lexicon);
    DECREF(self->plist);
    DECREF(self->lex_temp_out);
    DECREF(self->post_temp_out);
    DECREF(self->skip_out);
    DECREF(self->lex_temp_in);
    DECREF(self->post_temp_in);
    DECREF(self->posting);
    DECREF(self->skip_stepper);
    DECREF(self->type);
    
    /* Setting these to 0 causes SortEx_Clear_Cache to avoid 
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
    RawPosting *const raw_post_a = *(RawPosting**)a;
    RawPosting *const raw_post_b = *(RawPosting**)b;
    const size_t a_len = raw_post_a->content_len;
    const size_t b_len = raw_post_b->content_len;
    const size_t len = a_len < b_len? a_len : b_len;
    int comparison = memcmp(raw_post_a->blob, raw_post_b->blob, len);
    UNUSED_VAR(self);

    if (comparison == 0) {
        /* If a is a substring of b, it's less than b, so return a neg num. */
        comparison = a_len - b_len;

        /* Break ties by doc id. */
        if (comparison == 0) {
            comparison = raw_post_a->doc_id - raw_post_b->doc_id;
        }
    }

    return comparison;
}

MemoryPool*
PostPool_get_mem_pool(PostingPool *self) { return self->mem_pool; }

void
PostPool_flip(PostingPool *self)
{
    u32_t i;
	u32_t num_runs = VA_Get_Size(self->runs);
    u32_t sub_thresh = num_runs > 0 
        ? self->mem_thresh / num_runs 
        : self->mem_thresh;

    PostPool_Sort_Cache(self);
    if (num_runs && (self->cache_max - self->cache_tick) > 0) {
        uint32_t num_items = PostPool_Cache_Count(self);
        /* Cheap imitation of flush. FIXME. */
        PostingPool *run = PostPool_new(self->schema, self->snapshot, 
            self->segment, self->polyreader, self->field, self->lex_writer, 
            self->mem_pool, self->lex_temp_out, self->post_temp_out, 
            self->skip_out);
        PostPool_Grow_Cache(run, num_items);
        memcpy(run->cache, self->cache + self->cache_tick, 
            num_items * sizeof(Obj*));
        run->cache_max = num_items;
        PostPool_Add_Run(self, (SortExternal*)run);
        self->cache_tick = 0;
        self->cache_max = 0;
    }

    /* Assign. */
    for (i = 0; i < num_runs; i++) {
        PostingPool *run = (PostingPool*)VA_Fetch(self->runs, i);
        if (run != NULL) {
            PostPool_Set_Mem_Thresh(run, sub_thresh);
            if (!run->lexicon) {
                S_fresh_flip(run, self->lex_temp_in, 
                    self->post_temp_in);
            }
        }
    }

    self->flipped = true;
}

void
PostPool_add_segment(PostingPool *self, SegReader *reader, I32Array *doc_map,
                     i32_t doc_base)
{
    LexiconReader *lex_reader = (LexiconReader*)SegReader_Fetch(reader,
        VTable_Get_Name(LEXICONREADER));
    Lexicon *lexicon = lex_reader 
        ?  LexReader_Lexicon(lex_reader, self->field, NULL)
        : NULL;

    if (lexicon) {
        PostingListReader *plist_reader = (PostingListReader*)SegReader_Fetch(reader, 
            VTable_Get_Name(POSTINGLISTREADER));
        PostingList *plist = plist_reader 
            ? PListReader_Posting_List(plist_reader, self->field, NULL) 
            : NULL;
        if (!plist) {
            THROW(ERR, "Got a Lexicon but no PostingList for '%o' in '%o'",
                self->field, SegReader_Get_Seg_Name(reader));
        }
        PostingPool *run = PostPool_new(self->schema, self->snapshot, 
            self->segment, self->polyreader, self->field, self->lex_writer, 
            self->mem_pool, self->lex_temp_out, self->post_temp_out, 
            self->skip_out);
        run->lexicon  = lexicon;
        run->plist    = plist;
        run->doc_base = doc_base;
        run->doc_map  = (I32Array*)INCREF(doc_map);
        PostPool_Add_Run(self, (SortExternal*)run);
    }
}

void
PostPool_shrink(PostingPool *self)
{
    if (self->cache_max - self->cache_tick > 0) {
        size_t cache_count = PostPool_Cache_Count(self);
        size_t size        = cache_count * sizeof(Obj*);
        if (self->cache_tick > 0) {
            Obj **start = self->cache + self->cache_tick;
            memmove(self->cache, start, size);
        }
        self->cache      = (Obj**)REALLOCATE(self->cache, size);
        self->cache_tick = 0;
        self->cache_max  = cache_count;
        self->cache_cap  = cache_count;
    } 
    else {
        FREEMEM(self->cache);
        self->cache      = NULL;
        self->cache_tick = 0;
        self->cache_max  = 0;
        self->cache_cap  = 0;
    }
    self->scratch_cap = 0;
    FREEMEM(self->scratch);
    self->scratch = NULL;

    /* It's not necessary to iterate over the runs, because they don't have
     * any cache costs until Refill() gets called. */
}

static Obj*
S_fetch_from_ram(PostingPool *self)
{
    if (self->cache_tick >= self->cache_max) {
        return NULL;
    }
    return self->cache[ self->cache_tick++ ];
}

void 
PostPool_flush(PostingPool *self)
{
    /* Don't add a run unless we have data to put in it. */
    if (PostPool_Cache_Count(self) == 0) { return; }

    PostingPool *run = PostPool_new(self->schema, self->snapshot, 
        self->segment, self->polyreader, self->field, self->lex_writer, 
        self->mem_pool, self->lex_temp_out, self->post_temp_out, 
        self->skip_out);
    PostingStreamer *streamer = (PostingStreamer*)RawPostStreamer_new(
        self->schema, self->snapshot, self->segment, self->polyreader, 
        self->post_temp_out);

    /* Write to temp files. */
    LexWriter_Enter_Temp_Mode(self->lex_writer, self->field, 
        self->lex_temp_out);
    run->lex_start  = OutStream_Tell(self->lex_temp_out);
    run->post_start = OutStream_Tell(self->post_temp_out);
    PostPool_Sort_Cache(self);
    S_write_terms_and_postings(self, streamer, S_fetch_from_ram, NULL);
    
    run->lex_end  = OutStream_Tell(self->lex_temp_out);
    run->post_end = OutStream_Tell(self->post_temp_out);
    LexWriter_Leave_Temp_Mode(self->lex_writer);

    /* Add the run to the array. */
    PostPool_Add_Run(self, (SortExternal*)run);
    PostPool_Clear_Cache(self);

    DECREF(streamer);
}

void
PostPool_finish(PostingPool *self)
{
    /* Bail if there's no data. */
    if (!PostPool_Peek(self)) { return; }

    PostingStreamer *streamer = Post_Make_Streamer(self->posting, 
        self->schema, self->snapshot, self->segment, self->polyreader,
        self->field_num);
    PostPool_fetch_t fetch 
        = (PostPool_fetch_t)METHOD(PostPool_Get_VTable(self), PostPool, Fetch);
    LexWriter_Start_Field(self->lex_writer, self->field_num);
    S_write_terms_and_postings(self, streamer, fetch, self->skip_out);
    LexWriter_Finish_Field(self->lex_writer, self->field_num);
    DECREF(streamer);
}

static void
S_write_terms_and_postings(PostingPool *self, PostingStreamer *streamer,
                           PostPool_fetch_t fetch, OutStream *skip_stream)
{
    TermInfo      *const tinfo          = TInfo_new(0);
    TermInfo      *const skip_tinfo     = TInfo_new(0);
    CharBuf       *const last_term_text = CB_new(0);
    LexiconWriter *const lex_writer     = self->lex_writer;
    SkipStepper   *const skip_stepper   = self->skip_stepper;
    i32_t          last_doc_id          = 0;
    i32_t          last_skip_doc        = 0;
    i64_t          last_skip_filepos    = 0;
    const i32_t    skip_interval
        = Arch_Skip_Interval(Schema_Get_Architecture(self->schema));

    /* Prime heldover variables. */
    RawPosting *posting = (RawPosting*)CERTIFY(fetch(self), RAWPOSTING);
    CB_Mimic_Str(last_term_text, posting->blob, posting->content_len);
    char *last_text_buf = (char*)CB_Get_Ptr8(last_term_text);
    u32_t last_text_size = CB_Get_Size(last_term_text);
    SkipStepper_Set_ID_And_Filepos(skip_stepper, 0, 0);

    while (1) {
        bool_t same_text_as_last = true;

        if (posting == NULL) {
            /* On the last iter, use an empty string to make 
             * LexiconWriter DTRT. */
            posting = &RAWPOSTING_BLANK;
            same_text_as_last = false;
        }
        else {
            /* Compare once. */
            if (   posting->content_len != last_text_size
                || memcmp(&posting->blob, last_text_buf, last_text_size) != 0
            ) {
                same_text_as_last = false;
            }
        }

        /* If the term text changes, process the last term. */
        if ( !same_text_as_last ) {
            /* Hand off to LexiconWriter. */
            LexWriter_Add_Term(lex_writer, last_term_text, tinfo);

            /* Start each term afresh. */
            TInfo_Reset(tinfo);
            PostStreamer_Start_Term(streamer, tinfo);

            /* Init skip data in preparation for the next term. */
            skip_stepper->doc_id  = 0;
            skip_stepper->filepos = tinfo->post_filepos;
            last_skip_doc         = 0;
            last_skip_filepos     = tinfo->post_filepos;

            /* Remember the term_text so we can write string diffs. */
            CB_Mimic_Str(last_term_text, posting->blob, 
                posting->content_len);
            last_text_buf  = (char*)CB_Get_Ptr8(last_term_text);
            last_text_size = CB_Get_Size(last_term_text);

            /* Starting a new term, thus a new delta doc sequence at 0. */
            last_doc_id = 0;
        }

        /* Bail on last iter before writing invalid posting data. */
        if (posting == &RAWPOSTING_BLANK) { break; }

        /* Write posting data. */
        PostStreamer_Write_Posting(streamer, posting);

        /* Doc freq lags by one iter. */
        tinfo->doc_freq++;

        /*  Write skip data. */
        if (   skip_stream != NULL
            && same_text_as_last   
            && tinfo->doc_freq % skip_interval == 0
            && tinfo->doc_freq != 0
        ) {
            /* If first skip group, save skip stream pos for term info. */
            if (tinfo->doc_freq == skip_interval) {
                tinfo->skip_filepos = OutStream_Tell(skip_stream); 
            }
            /* Write deltas. */
            last_skip_doc         = skip_stepper->doc_id;
            last_skip_filepos     = skip_stepper->filepos;
            skip_stepper->doc_id  = posting->doc_id;
            PostStreamer_Update_Skip_Info(streamer, skip_tinfo);
            skip_stepper->filepos = skip_tinfo->post_filepos;
            SkipStepper_Write_Record(skip_stepper, skip_stream,
                 last_skip_doc, last_skip_filepos);
        }

        /* Remember last doc id because we need it for delta encoding. */
        last_doc_id = posting->doc_id;

        /* Retrieve the next posting from the sort pool. */
        /* DECREF(posting); */ /* No!!  DON'T destroy!!!  */
        posting = (RawPosting*)fetch(self);
    }

    /* Clean up. */
    DECREF(last_term_text);
    DECREF(skip_tinfo);
    DECREF(tinfo);
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
                if (term_text && !Obj_Is_A((Obj*)term_text, CHARBUF)) {
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
        if (num_elems >= self->cache_cap) {
            size_t new_cap = Memory_oversize(num_elems + 1, sizeof(Obj*));
            PostPool_Grow_Cache(self, new_cap);
        }
        self->cache[ num_elems ] = (Obj*)raw_posting;
        num_elems++;
    }

    /* Reset the cache array position and length; remember file pos. */
    self->cache_max   = num_elems;
    self->cache_tick  = 0;

    return num_elems;
}

void
PostPool_set_lex_temp_in(PostingPool *self, InStream *instream)
{
    DECREF(self->lex_temp_in);
    self->lex_temp_in = instream;
}

void
PostPool_set_post_temp_in(PostingPool *self, InStream *instream)
{
    DECREF(self->post_temp_in);
    self->post_temp_in = instream;
}

void
PostPool_add_inversion(PostingPool *self, Inversion *inversion, i32_t doc_id, 
                       float doc_boost, float length_norm)
{
    Post_Add_Inversion_To_Pool(self->posting, self, inversion, 
        self->type, doc_id, doc_boost, length_norm);
}

static void
S_fresh_flip(PostingPool *self, InStream *lex_temp_in, 
             InStream *post_temp_in)
{
    if (self->flipped) { THROW(ERR, "Can't Flip twice"); }
    self->flipped = true;

    /* Sort RawPostings in cache, if any. */
    PostPool_Sort_Cache(self);

    /* Bail if never flushed. */
    if (self->lex_end == 0) { return; }

    /* Get a Lexicon. */
    CharBuf *lex_alias = CB_newf("%o-%i64-to-%i64",
        InStream_Get_Filename(lex_temp_in), self->lex_start, self->lex_end);
    InStream *lex_temp_in_dupe = InStream_Reopen(lex_temp_in, 
        lex_alias, self->lex_start, self->lex_end - self->lex_start);
    self->lexicon = (Lexicon*)RawLex_new(self->schema, self->field, 
        lex_temp_in_dupe, 0, self->lex_end - self->lex_start);
    DECREF(lex_alias);
    DECREF(lex_temp_in_dupe);

    /* Get a PostingList. */
    CharBuf *post_alias = CB_newf("%o-%i64-to-%i64",
        InStream_Get_Filename(post_temp_in), self->post_start, 
        self->post_end);
    InStream *post_temp_in_dupe = InStream_Reopen(post_temp_in, 
        post_alias, self->post_start, self->post_end - self->post_start);
    self->plist = (PostingList*)RawPList_new(self->schema, self->field, 
        post_temp_in_dupe, 0, self->post_end - self->post_start);
    DECREF(post_alias);
    DECREF(post_temp_in_dupe);
}

/* Copyright 2007-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

