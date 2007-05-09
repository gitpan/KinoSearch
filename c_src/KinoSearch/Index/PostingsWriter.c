#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_POSTINGSWRITER_VTABLE
#include "KinoSearch/Index/PostingsWriter.r"

#include "KinoSearch/Posting.r"
#include "KinoSearch/Posting/RawPosting.r"
#include "KinoSearch/Schema.r"
#include "KinoSearch/InvIndex.r"
#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Index/PostingPool.r"
#include "KinoSearch/Index/PostingPoolQueue.r"
#include "KinoSearch/Index/PreSorter.r"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/SkipStepper.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Index/LexWriter.r"
#include "KinoSearch/Index/TermStepper.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Util/IntMap.r"
#include "KinoSearch/Util/MemoryPool.r"

/* Initialize a PostingPool for this field.  If this is the field's first
 * pool, create a VArray to hold this and subsequent pools.
 */
static void
init_posting_pool(PostingsWriter *self, const ByteBuf *field_name);

/* Flush at least 75% of the acculumulated RAM cache to disk.
 */
static void 
flush_pools(PostingsWriter *self);

/* Write terms and postings to outstreams -- possibly temp, possibly real.
 */
static void
write_terms_and_postings(PostingsWriter *self, Obj *raw_post_source, 
                         OutStream *post_stream, OutStream *skip_stream);

PostingsWriter*
PostWriter_new(InvIndex *invindex, SegInfo *seg_info, 
               LexWriter *lex_writer, PreSorter *pre_sorter, 
               chy_u32_t mem_thresh)
{
    u32_t arena_size = mem_thresh < 0x1000000 ? mem_thresh : 0x1000000;

    CREATE(self, PostingsWriter, POSTINGSWRITER);

    /* assign */
    REFCOUNT_INC(invindex)
    REFCOUNT_INC(seg_info);
    REFCOUNT_INC(lex_writer);
    if (pre_sorter != NULL)
        REFCOUNT_INC(pre_sorter);
    self->invindex      = invindex;
    self->seg_info      = seg_info;
    self->lex_writer    = lex_writer;
    self->pre_sorter    = pre_sorter;
    self->mem_thresh    = mem_thresh;

    /* derive */
    self->lex_tempname  =  BB_CLONE(seg_info->seg_name);
    self->post_tempname =  BB_CLONE(seg_info->seg_name);
    BB_Cat_Str(self->lex_tempname, ".lextemp", 8);
    BB_Cat_Str(self->post_tempname, ".ptemp", 6);

    /* init */
    self->post_pools    = VA_new(Schema_Num_Fields(invindex->schema));
    self->skip_stream   = NULL;
    self->skip_stepper  = SkipStepper_new();
    self->mem_pool      = MemPool_new(arena_size);
    self->lex_instream  = NULL;
    self->post_instream = NULL;

    /* open cache streams */
    self->lex_outstream = Folder_Open_OutStream(self->invindex->folder, 
        self->lex_tempname);
    self->post_outstream = Folder_Open_OutStream(self->invindex->folder, 
        self->post_tempname);

    return self;
}

void
PostWriter_destroy(PostingsWriter *self)
{
    REFCOUNT_DEC(self->invindex);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->lex_writer);
    REFCOUNT_DEC(self->pre_sorter);
    REFCOUNT_DEC(self->mem_pool);
    REFCOUNT_DEC(self->post_pools);
    REFCOUNT_DEC(self->skip_stepper);
    REFCOUNT_DEC(self->lex_tempname);
    REFCOUNT_DEC(self->post_tempname);
    REFCOUNT_DEC(self->lex_outstream);
    REFCOUNT_DEC(self->post_outstream);
    REFCOUNT_DEC(self->lex_instream);
    REFCOUNT_DEC(self->post_instream);
    REFCOUNT_DEC(self->skip_stream);
    free(self);
}

static void
init_posting_pool(PostingsWriter *self, const ByteBuf *field_name)
{
    Schema      *schema     = self->invindex->schema;
    i32_t        field_num  = SegInfo_Field_Num(self->seg_info, field_name);
    VArray      *field_post_pools = (VArray*)VA_Fetch(self->post_pools, 
        field_num);
    TermStepper *term_stepper = TermStepper_new(field_name,
        self->lex_writer->skip_interval, false);
    IntMap      *pre_sort_remap = self->pre_sorter == NULL
                                    ? NULL
                                    : PreSorter_Gen_Remap(self->pre_sorter);
    PostingPool *post_pool  = PostPool_new(schema, field_name, term_stepper, 
        self->mem_pool, pre_sort_remap);
    REFCOUNT_DEC(term_stepper);

    if (field_post_pools == NULL) {
        field_post_pools = VA_new(1);
        VA_Store(self->post_pools, field_num, (Obj*)field_post_pools);
        REFCOUNT_DEC(field_post_pools);
    }

    /* make sure the first pool in the array always has space */
    VA_Unshift(field_post_pools, (Obj*)post_pool);

    REFCOUNT_DEC(post_pool);
}

void
PostWriter_add_batch(PostingsWriter *self, struct kino_TokenBatch *batch, 
                     const ByteBuf *field_name, i32_t doc_num, 
                     float doc_boost, float length_norm)
{
    i32_t         field_num  = SegInfo_Field_Num(self->seg_info, field_name);
    PostingPool  *post_pool;
    VArray       *field_post_pools;
    
    /* retrive the current PostingPool for this field */
    field_post_pools = (VArray*)VA_Fetch(self->post_pools, field_num);
    if (field_post_pools == NULL) {
        init_posting_pool(self, field_name);
        field_post_pools = (VArray*)VA_Fetch(self->post_pools, field_num);
    }
    post_pool = (PostingPool*)VA_Fetch(field_post_pools, 0);

    /* add the TokenBatch to the PostingPool */
    PostPool_Add_Batch(post_pool, batch, doc_num, doc_boost, length_norm);

    /* check if we've crossed the memory threshold and it's time to flush */
    if (self->mem_pool->consumed > self->mem_thresh)
        flush_pools(self);
}

static void 
flush_pools(PostingsWriter *self)
{
    u32_t i;
    VArray *const post_pools = self->post_pools;

    /* refresh remap used by PostingPool objects */
    if (self->pre_sorter != NULL)
        PreSorter_Gen_Remap(self->pre_sorter);

    for (i = 0; i < self->post_pools->size; i++) {
        VArray *field_post_pools = (VArray*)VA_Fetch(post_pools, i);
        if (field_post_pools != NULL) {
            /* the first pool in the array is the only active pool */
            PostingPool *const post_pool 
                = (PostingPool*)VA_Fetch(field_post_pools, 0);

            if (post_pool->cache_max != post_pool->cache_tick) {
                /* open a skip stream if it hasn't been already */
                if (self->skip_stream == NULL) {
                    ByteBuf *filename = BB_CLONE(self->seg_info->seg_name);
                    BB_Cat_Str(filename, ".skip", 5);
                    self->skip_stream = Folder_Open_OutStream(
                        self->invindex->folder, filename);
                    REFCOUNT_DEC(filename);
                }

                /* write to temp files */
                LexWriter_Enter_Temp_Mode(self->lex_writer, 
					self->lex_outstream);
                post_pool->lex_start = OutStream_STell(self->lex_outstream);
                post_pool->post_start = OutStream_STell(self->post_outstream);
                PostPool_Sort_Cache(post_pool);
                write_terms_and_postings(self, (Obj*)post_pool, 
                    self->post_outstream, self->skip_stream);
                post_pool->lex_end = OutStream_STell(self->lex_outstream);
                post_pool->post_end = OutStream_STell(self->post_outstream);
                LexWriter_Leave_Temp_Mode(self->lex_writer);

                /* store away this pool and start another */
                init_posting_pool(self, post_pool->field_name);
            }
        }
    }

    /* now that we've flushed all RawPostings, release memory */
    MemPool_Release_All(self->mem_pool);
}

typedef RawPosting*
(*fetcher_t)(Obj *raw_post_source);

static void
write_terms_and_postings(PostingsWriter *self, Obj *raw_post_source, 
                         OutStream *post_stream, OutStream *skip_stream)
{
    TermInfo         *const tinfo           = TInfo_new(0,0,0,0);
    SkipStepper      *const skip_stepper    = self->skip_stepper;
    LexWriter        *const lex_writer      = self->lex_writer;
    const i32_t       skip_interval         = lex_writer->skip_interval;
    ByteBuf          *const last_term_text  = BB_new(0);
    u32_t             last_doc_num          = 0;
    u32_t             last_skip_doc         = 0;
    u64_t             last_skip_filepos     = 0;
    RawPosting       *posting               = NULL;
    fetcher_t         fetch                 = NULL;
    IntMap           *pre_sort_remap        = self->pre_sorter == NULL
        ? NULL
        :  PreSorter_Gen_Remap(self->pre_sorter);

    /* cache fetch method (violates OO principles, but we'll deal) */
    if (OBJ_IS_A(raw_post_source, POSTINGPOOL)) {
        fetch = (fetcher_t)((PostingPool*)raw_post_source)->_->fetch_from_ram;
    }
    else if (OBJ_IS_A(raw_post_source, POSTINGPOOLQUEUE)) {
        fetch = (fetcher_t)((PostingPoolQueue*)raw_post_source)->_->fetch;
    }

    /* prime heldover variables */
    SkipStepper_Reset(skip_stepper, 0, 0);
    posting = fetch(raw_post_source);
    if (posting == NULL)
        CONFESS("Failed to retrieve at least one posting");
    BB_Copy_Str(last_term_text, posting->blob, posting->content_len);

    while (1) {
        bool_t same_text_as_last = true;

        if (posting == NULL) {
            /* on the last iter, use an empty string to make LexWriter DTRT */
            posting = &RAWPOSTING_BLANK;
            same_text_as_last = false;
        }
        else {
            /* compare once */
            if (   posting->content_len != last_term_text->len  
                || memcmp(&posting->blob, last_term_text->ptr, 
                    posting->content_len) != 0
            ) {
                same_text_as_last = false;
            }

            /* remap doc num if necessary */
            if (pre_sort_remap != NULL)
                posting->doc_num 
                    = IntMap_Get(pre_sort_remap, posting->doc_num);

            /*  write skip data */
            if (   skip_stream != NULL
                && same_text_as_last   
                && tinfo->doc_freq % skip_interval == 0
                && tinfo->doc_freq != 0
            ) {
                /* if first skip group, save skip stream pos for term info */
                if (tinfo->doc_freq == skip_interval) {
                    tinfo->skip_filepos = OutStream_STell(skip_stream); 
                }
                /* write deltas */
                last_skip_doc         = skip_stepper->doc_num;
                last_skip_filepos     = skip_stepper->filepos;
                skip_stepper->doc_num = posting->doc_num;
                skip_stepper->filepos = OutStream_STell(post_stream);
                SkipStepper_Write_Record(skip_stepper, skip_stream,
                     last_skip_doc, last_skip_filepos);
            }
        }

        /* if the term text changes, process the last term */
        if ( !same_text_as_last ) {
            /* take note of where we are for the term dictionary */
            u64_t post_filepos = OutStream_STell(post_stream);

            /* hand off to LexWriter */
            LexWriter_Add(lex_writer, last_term_text, tinfo);

            /* start each term afresh */
            tinfo->doc_freq      = 0;
            tinfo->post_filepos  = post_filepos;
            tinfo->skip_filepos  = 0;
            tinfo->index_filepos = 0;

            /* init skip data in preparation for the next term */
            skip_stepper->doc_num = 0;
            skip_stepper->filepos = post_filepos;
            last_skip_doc         = 0;
            last_skip_filepos     = post_filepos;

            /* remember the term_text so we can write string diffs */
            BB_Copy_Str(last_term_text, posting->blob, 
                posting->content_len);

            /* starting a new term, thus a new delta doc sequence at 0 */
            last_doc_num    = 0;
        }

        /* bail on last iter before writing invalid posting data */
        if (posting == &RAWPOSTING_BLANK)
            break;

        /* write posting data */
        RawPost_Write_Record(posting, post_stream, last_doc_num);

        /* remember last doc num because we need it for delta encoding */
        last_doc_num = posting->doc_num;

        /* retrieve the next posting from the sort pool */
        /* REFCOUNT_DEC(posting); */ /* No!!  DON'T destroy!!!  */
        posting = fetch(raw_post_source);

        /* doc freq lags by one iter */
        tinfo->doc_freq++;
    }

    /* clean up */
    REFCOUNT_DEC(tinfo);
    REFCOUNT_DEC(last_term_text);
}

static void
finish_field(PostingsWriter *self, i32_t field_num)
{
    VArray *field_post_pools = (VArray*)VA_Fetch(self->post_pools, field_num);
    PostingPoolQueue *pool_q;
    IntMap      *pre_sort_remap = self->pre_sorter == NULL
                                    ? NULL
                                    : PreSorter_Gen_Remap(self->pre_sorter);
    
    if (field_post_pools == NULL)
        return;
    else
        /* TODO: can reusing mem_thresh double ram footprint? */
        pool_q = PostPoolQ_new(field_post_pools, self->lex_instream,
            self->post_instream, pre_sort_remap, self->mem_thresh); 

    /* don't bother unless there's actually content */
    if (PostPoolQ_Peek(pool_q) != NULL) {
        LexWriter        *lex_writer    = self->lex_writer;
        Folder           *folder        = self->invindex->folder;
        OutStream        *post_stream   = NULL;
        OutStream        *skip_stream   = self->skip_stream;
        ByteBuf          *filename      = BB_CLONE(self->seg_info->seg_name);

        /* open posting stream */
        BB_Cat_Str(filename, ".p", 2);
        BB_Cat_I64(filename, (i64_t)field_num);
        post_stream = Folder_Open_OutStream(folder, filename);
    
        /* open a skip stream if it hasn't been already */
        if (self->skip_stream == NULL) {
            ByteBuf *skip_filename = BB_CLONE(self->seg_info->seg_name);
            BB_Cat_Str(skip_filename, ".skip", 5);
            skip_stream = Folder_Open_OutStream(folder, skip_filename);
            self->skip_stream = skip_stream;
            REFCOUNT_DEC(skip_filename);
        }

        /* start LexWriter */
        LexWriter_Start_Field(lex_writer, field_num);

        /* write terms and postings */
        write_terms_and_postings(self, (Obj*)pool_q, post_stream, 
			skip_stream);

        /* finish and clean up */
        LexWriter_Finish_Field(self->lex_writer, field_num);
        OutStream_SClose(post_stream);
        REFCOUNT_DEC(post_stream);
        REFCOUNT_DEC(filename);
    }

    /* clean up */
    REFCOUNT_DEC(pool_q);
}

void
PostWriter_add_seg_data(PostingsWriter *self, Folder *other_folder, 
                        SegInfo *other_seg_info, IntMap *doc_map)
{
    u32_t      i;
    VArray    *post_pools     = self->post_pools;
    Schema    *schema         = self->invindex->schema;
    SegInfo   *seg_info       = self->seg_info;
    VArray    *all_fields     = Schema_All_Fields(schema);
    IntMap    *pre_sort_remap = self->pre_sorter == NULL
                                    ? NULL
                                    : PreSorter_Gen_Remap(self->pre_sorter);

    for (i = 0; i < all_fields->size; i++) {
        ByteBuf *field_name = (ByteBuf*)VA_Fetch(all_fields, i);
        i32_t old_field_num = SegInfo_Field_Num(other_seg_info, field_name);
        i32_t new_field_num = SegInfo_Field_Num(seg_info, field_name);
        VArray *field_post_pools   = NULL;
        PostingPool *post_pool     = NULL;
        TermStepper *stepper       = NULL;

        /* sanity check */
        if (old_field_num == -1)
            continue; /* not in old segment */
        if (new_field_num == -1)
            CONFESS("Unrecognized field: %s", field_name->ptr);

        /* init field if we've never seen it before */
        field_post_pools = (VArray*)VA_Fetch(post_pools, new_field_num);
        if (field_post_pools == NULL) {
            init_posting_pool(self, field_name);
            field_post_pools 
                = (VArray*)VA_Fetch(self->post_pools, new_field_num);
        }

        /* create a pool and add it to the field's collection of pools */
        stepper = TermStepper_new(field_name,
            self->lex_writer->skip_interval, false);
        post_pool = PostPool_new(schema, field_name, stepper, 
            self->mem_pool, pre_sort_remap);
        PostPool_Assign_Seg(post_pool, other_folder, other_seg_info, 
            seg_info->doc_count, doc_map);
        VA_Push(field_post_pools, (Obj*)post_pool);
        REFCOUNT_DEC(stepper);
        REFCOUNT_DEC(post_pool);
    }

    /* clean up */
    REFCOUNT_DEC(all_fields);
}

void
PostWriter_finish(PostingsWriter *self)
{
    Folder *folder = self->invindex->folder;
    u32_t i;
    Hash *metadata = Hash_new(0);

    /* switch temp streams from write to read mode */
    OutStream_SClose(self->lex_outstream);
    OutStream_SClose(self->post_outstream);
    self->lex_instream  = Folder_Open_InStream(folder, self->lex_tempname);
    self->post_instream = Folder_Open_InStream(folder, self->post_tempname);

    /* write postings for each field */
    for (i = 0; i < self->post_pools->size; i++) {
        finish_field(self, i);
    }

    /* close down */
    if (self->skip_stream != NULL)
        OutStream_SClose(self->skip_stream);
    
    /* generate and store metadata */
    Hash_Store_I64(metadata, "format", 6, (i64_t)POSTING_LIST_FORMAT);
    SegInfo_Add_Metadata(self->seg_info, "posting_list", 12, (Obj*)metadata); 

    /* dispatch the LexWriter */
    LexWriter_Finish(self->lex_writer);

    /* clean up */
    REFCOUNT_DEC(metadata);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

