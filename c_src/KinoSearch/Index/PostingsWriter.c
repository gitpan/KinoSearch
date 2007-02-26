#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#include <stdio.h>

#define KINO_WANT_POSTINGSWRITER_VTABLE
#include "KinoSearch/Index/PostingsWriter.r"

#include "KinoSearch/Analysis/Token.r"
#include "KinoSearch/Analysis/TokenBatch.r"
#include "KinoSearch/Schema/FieldSpec.r"
#include "KinoSearch/Schema.r"
#include "KinoSearch/InvIndex.r"
#include "KinoSearch/Index/TermListReader.r"
#include "KinoSearch/Index/SegTermList.r"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/SegTermDocs.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Index/TermListWriter.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Util/IntMap.r"
#include "KinoSearch/Util/SortExternal.r"

/* Break up a serialized posting into its constituent parts.
 */
static void 
deserialize(ByteBuf *posting, ViewByteBuf *term_text, ViewByteBuf *positions, 
            i32_t *field_num_ptr, u32_t *doc_num_ptr, u32_t *freq_ptr);

PostingsWriter*
PostWriter_new(InvIndex *invindex, SegInfo *seg_info)
{
    CREATE(self, PostingsWriter, POSTINGSWRITER);

    /* assign */
    REFCOUNT_INC(invindex)
    REFCOUNT_INC(seg_info);
    self->invindex    = invindex;
    self->seg_info    = seg_info;

    /* init */
    self->sort_pool = SortEx_new(invindex, seg_info, 0);

    return self;
}

void
PostWriter_destroy(PostingsWriter *self)
{
    REFCOUNT_DEC(self->invindex);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->sort_pool);
    free(self);
}

#define FIELD_NUM_LEN 2
#define DOC_NUM_LEN 4
#define FIELD_BOOST_LEN 1
#define TEXT_LEN_LEN 2
#define NULL_BYTE_LEN 1 
#define MAX_VINT_LEN 5
#define FREQ_MAX_LEN 5 /* same as max vint len */

void
PostWriter_add_batch(PostingsWriter *self, TokenBatch *batch, 
                     FieldSpec *fspec, kino_i32_t doc_num, float doc_boost, 
                     float length_norm)
{
    SortExternal *sort_pool = self->sort_pool;
    u16_t         field_num = SegInfo_Field_Num(self->seg_info, fspec->name);
    Similarity   *sim = Schema_Fetch_Sim(self->invindex->schema, fspec->name);
    float         field_boost = doc_boost * fspec->boost * length_norm;
    char         doc_num_buf[4];
    char         field_num_buf[2];
    Token      **tokens;
    u32_t        freq;
    const bool_t store_field_boost = fspec->store_field_boost;
    const bool_t store_pos_boost   = fspec->store_pos_boost;
    const u8_t   field_boost_byte  = Sim_Encode_Norm(sim, field_boost);

    /* cache serialized doc num and field num in anticipation of loop */
    Math_encode_bigend_u32(doc_num, doc_num_buf);
    Math_encode_bigend_u16(field_num, field_num_buf);

    TokenBatch_Reset(batch);
    while ( (tokens = TokenBatch_Next_Cluster(batch, &freq)) != NULL ) {
        Token   *token = *tokens;
        size_t len   = FIELD_NUM_LEN
                     + token->len
                     + NULL_BYTE_LEN
                     + DOC_NUM_LEN
                     + ( store_field_boost ? FIELD_BOOST_LEN : 0 )
                     + FREQ_MAX_LEN
                     + (MAX_VINT_LEN * freq) /* positions */
                     + ( store_pos_boost ? (sizeof(u8_t) * freq) : 0 )
                     + TEXT_LEN_LEN
                     + NULL_BYTE_LEN;
        ByteBuf *serialized_bb = BB_new(len);
        char *dest = serialized_bb->ptr;
        u32_t i;
        u32_t last_prox = 0;

        /* field number */
        memcpy(dest, field_num_buf, FIELD_NUM_LEN);
        dest += FIELD_NUM_LEN;

        /* token text, plus null byte */
        memcpy(dest, token->text, token->len);
        dest += token->len;
        *dest = '\0';
        dest += NULL_BYTE_LEN;

        /* doc num */
        memcpy(dest, doc_num_buf, DOC_NUM_LEN);
        dest += DOC_NUM_LEN;

        /* freq */
        dest += OutStream_encode_vint(freq, dest);

        /* field_boost */
        if (store_field_boost) {
            *((u8_t*)dest) = field_boost_byte;
            dest++;
        }

        /* positions and boosts */
        for (i = 0; i < freq; i++) {
            Token *const t = tokens[i];
            const u32_t prox_delta = t->pos - last_prox;
            const float boost = field_boost * t->boost;

            dest += OutStream_encode_vint(prox_delta, dest);
            last_prox = t->pos; 

            if (store_pos_boost) {
                *((u8_t*)dest) = Sim_Encode_Norm(sim, boost); 
                dest++;
            }
        }

        /* encode the length of the term text as a bigend u16 */
        if (token->len > 65535) 
            CONFESS("Maximum token length is 65535; got %d", token->len);
        Math_encode_bigend_u16(token->len, dest);
        dest += TEXT_LEN_LEN;

        *dest = '\0';
        serialized_bb->len = dest - serialized_bb->ptr;

        SortEx_Feed_BB(sort_pool, serialized_bb);
        REFCOUNT_DEC(serialized_bb);
    }
}

void
PostWriter_write_postings(PostingsWriter *self, TermListWriter *tl_writer)
{
    Folder        *folder              = self->invindex->folder;
    SortExternal  *sort_pool           = self->sort_pool;
    ByteBuf       *seg_name            = self->seg_info->seg_name;
    ByteBuf       *posting             = BB_new(40);
    ViewByteBuf   *posboosts           = ViewBB_new(NULL, 0);
    ViewByteBuf   *term_text           = ViewBB_new(NULL, 0);
    ByteBuf       *last_term_text      = BB_new(40);
    TermInfo      *tinfo               = TInfo_new(I32_MAX,0,0,0,0);
    u32_t          last_doc_num        = 0;
    i32_t          field_num           = 0;
    u32_t          last_skip_doc       = 0;
    u64_t          last_skip_post_ptr  = 0.0;
    i32_t          iter                = 0;
    u32_t         *skip_doc_data       = NULL;
    u64_t         *skip_fileptr_data   = NULL;
    u32_t          num_skips           = 0;
    u32_t          skip_alloc          = 0;
    OutStream     *outstream           = NULL;
    ByteBuf       *filename            = BB_new(seg_name->len + 10);

    /* each loop is one field, one term, one doc_num, many positions */
    while (1) {
        u32_t doc_num = 0;
        u32_t freq    = 0;

        /* retrieve the next posting from the sort pool */
        REFCOUNT_DEC(posting);
        posting = SortEx_Fetch(sort_pool);

        /* SortExternal returns NULL when exhausted */
        if (posting == NULL) {
            goto FINAL_ITER;
        }

        /* each iter, add a doc to the doc_freq for a given term */
        iter++;
        tinfo->doc_freq++;    /* lags by 1 iter */

        /* break up the serialized posting into its parts */
        deserialize(posting, term_text, posboosts, &field_num, &doc_num, 
            &freq);

        if (field_num != tinfo->field_num) {
            if (outstream != NULL) 
                OutStream_SClose(outstream);
            REFCOUNT_DEC(outstream);

            filename->len = sprintf(filename->ptr, "%s.p%ld", seg_name->ptr, 
                (long)field_num); 
            outstream = Folder_Open_OutStream(folder, filename);
        }

        /* on the first iter, prime the "heldover" variables */
        if (iter == 1) {
            BB_Copy_BB(last_term_text, (ByteBuf*)term_text);
            tinfo->doc_freq      = 0;
            tinfo->post_fileptr  = OutStream_STell(outstream);
            tinfo->skip_offset   = OutStream_STell(outstream);
            tinfo->index_fileptr = 0;
            tinfo->field_num     = field_num;
        }


        if ( iter == -1 ) { /* never true; can only get here via goto */
            /* prepare to clear out buffers and exit loop */
            FINAL_ITER: {
                iter = -1;
                REFCOUNT_DEC(term_text);
                term_text = (ViewByteBuf*)BB_new(0);
                tinfo->doc_freq++;
            }
        }

        /* create skipdata */
        if ( (tinfo->doc_freq + 1) % tl_writer->skip_interval == 0 ) {
            u64_t post_ptr = OutStream_STell(outstream);

            if (num_skips >= skip_alloc) {
                skip_alloc = num_skips + 1;
                skip_doc_data = REALLOCATE(skip_doc_data, skip_alloc, u32_t);
                skip_fileptr_data = REALLOCATE(skip_fileptr_data, 
                    skip_alloc, u64_t);
            }

            skip_doc_data[num_skips]     = last_doc_num - last_skip_doc;
            skip_fileptr_data[num_skips] = post_ptr - last_skip_post_ptr;

            last_skip_doc      = last_doc_num;
            last_skip_post_ptr = post_ptr;
            num_skips++;
        }

        /* if either the term or fieldnum changes, process the last term */
        if (   field_num != tinfo->field_num
            || BB_compare(&term_text, &last_term_text) 
        ) {
            /* take note of where we are for the term dictionary */
            u64_t post_ptr = OutStream_STell(outstream);

            /* write skipdata if there is any */
            if (num_skips) {
                /* kludge to compensate for doc_freq's 1-iter lag */
                if (
                    (tinfo->doc_freq + 1) % tl_writer->skip_interval == 0 
                ) {
                    /* remove 1 cycle of skip data */
                    num_skips--;
                }
                if (num_skips) {
                    u32_t i;

                    /* tell tl_writer about the non-zero skip amount */
                    tinfo->skip_offset = post_ptr - tinfo->post_fileptr;

                    /* write out the skip data */
                    for (i = 0; i < num_skips; i++) {
                        OutStream_Write_VInt(outstream, skip_doc_data[i]);
                        OutStream_Write_VLong(outstream, skip_fileptr_data[i]);
                    }
                    num_skips = 0;

                    /* update the filepointer for the file we just wrote to */
                    post_ptr = OutStream_STell(outstream);
                }
            }

            /* init skip data in preparation for the next term */
            last_skip_doc     = 0;
            last_skip_post_ptr = post_ptr;

            /* hand off to TermListWriter */
            TLWriter_Add(tl_writer, last_term_text, tinfo);

            /* start each term afresh */
            tinfo->doc_freq      = 0;
            tinfo->post_fileptr  = post_ptr;
            tinfo->skip_offset   = 0;
            tinfo->index_fileptr = 0;

            /* Update the field num in the tinfo */
            tinfo->field_num = field_num;

            /* remember the term_text so we can write string diffs */
            BB_Copy_BB(last_term_text, (ByteBuf*)term_text);

            last_doc_num    = 0;
        }

        /* break out of loop on last iter before writing invalid data */
        if (iter == -1)
            break;

        /* write freq data */
        /* doc_code is delta doc_num, shifted left by 1. */
        if (freq == 1) {
            /* set low bit of doc_code to 1 to indicate freq of 1 */
            const u32_t doc_code = ((doc_num - last_doc_num) << 1 ) + 1;
            OutStream_Write_VInt(outstream, doc_code);
        }
        else {
            const u32_t doc_code = (doc_num - last_doc_num) << 1;
            /* leave low bit of doc_code at 0, record explicit freq */
            OutStream_Write_VInt(outstream, doc_code);
            OutStream_Write_VInt(outstream, freq);
        }

        /*  write positions and boost bytes */
        OutStream_Write_Bytes(outstream, posboosts->ptr, posboosts->len);

        /* remember last doc num because we need it for delta encoding */
        last_doc_num = doc_num;
    }

    /* clean up */
    if (outstream != NULL) {
        OutStream_SClose(outstream);
        REFCOUNT_DEC(outstream);
    }
    REFCOUNT_DEC(filename);
    REFCOUNT_DEC(tinfo);
    REFCOUNT_DEC(term_text);
    REFCOUNT_DEC(last_term_text);
    REFCOUNT_DEC(posboosts);
    REFCOUNT_DEC(posting); 
    free(skip_doc_data);
    free(skip_fileptr_data);
}

void
PostWriter_add_segment(PostingsWriter *self, TermListReader* tl_reader, 
                       SegTermDocs *term_docs, IntMap *doc_map, 
                       IntMap *field_num_map) 
{
    Schema       *schema     = self->invindex->schema;
    SegInfo      *seg_info   = self->seg_info;
    SortExternal *sort_pool  = self->sort_pool;
    const i32_t   num_fields = field_num_map == NULL 
        ? (i32_t)Schema_Num_Fields(schema)
        : (i32_t)field_num_map->size;
    i32_t         max_doc    = doc_map->size;
    ByteBuf      *posting    = BB_new(FIELD_NUM_LEN);
    SegTermList  *term_list  = NULL;
    char doc_num_buf[4];
    char text_len_buf[4];
    i32_t orig_field_num = -1;
    i32_t field_num      = -1;
    bool_t store_field_boost = false;
    bool_t store_pos_boost   = false;

    /* seed term list iteration */
    while (1) {
        Term *term;
        size_t common_len;

        /* proceed to next term */
        if (term_list == NULL || !SegTermList_Next(term_list)) {
            ByteBuf   *field_name = NULL;
            FieldSpec *field_spec = NULL;

            /* get the term list for the next indexed field with content */
            while (++orig_field_num < num_fields) {
                REFCOUNT_DEC(term_list);
                field_num = field_num_map == NULL
                    ? orig_field_num
                    : IntMap_Get(field_num_map, orig_field_num);
                field_name = SegInfo_Field_Name(seg_info, field_num);
                term_list = TLReader_Start_Field_Terms(tl_reader, field_name);
                if (term_list != NULL && SegTermList_Next(term_list))
                    break;
            }

            /* bail out of loop when all fields exhausted */
            if (orig_field_num >= num_fields) {
                REFCOUNT_DEC(term_list);
                break;
            }

            /* start with field num */
            Math_encode_bigend_u16(field_num, posting->ptr);

            /* get field characteristics */
            field_spec = Schema_Fetch_FSpec(schema, field_name);
            store_pos_boost   = field_spec->store_pos_boost;
            store_field_boost = field_spec->store_field_boost;
            
        }
        term       = SegTermList_Get_Term(term_list);
        common_len = term->text->len + FIELD_NUM_LEN;

        /* continue with term text and null byte */
        Math_encode_bigend_u16(term->text->len, text_len_buf);
        posting->len = FIELD_NUM_LEN;
        BB_Cat_BB(posting, term->text);
        BB_Cat_Str(posting, "\0", NULL_BYTE_LEN);
        common_len += NULL_BYTE_LEN;

        SegTermDocs_Seek_TL(term_docs, (TermList*)term_list);
        while (SegTermDocs_Next(term_docs)) {
            i32_t doc_num          = SegTermDocs_Get_Doc(term_docs);
            u32_t freq             = SegTermDocs_Get_Freq(term_docs);
            ByteBuf *positions_bb  = SegTermDocs_Get_Positions(term_docs);
            u32_t *positions       = (u32_t*)positions_bb->ptr;
            ByteBuf *boosts_bb     = SegTermDocs_Get_Boosts(term_docs);
            u8_t *boosts           = (u8_t*)boosts_bb->ptr;
            size_t new_size        = 
                  common_len         /* field num, term text, null byte */
                + DOC_NUM_LEN 
                + ( store_field_boost ? FIELD_BOOST_LEN : 0 )
                + FREQ_MAX_LEN
                + (MAX_VINT_LEN * freq) /* positions */
                + ( store_pos_boost ? (sizeof(u8_t) * freq) : 0 )
                + TEXT_LEN_LEN
                + NULL_BYTE_LEN;
            char *dest;
            u32_t num_bytes;
            u32_t i;
            u32_t last_prox = 0;
            
            /* grow if necessary and get a pointer to write to */
            BB_Grow(posting, new_size); /* crucial to allocate enough! */
            dest = posting->ptr;

            /* fast forward past field number and term text */
            dest += common_len;

            /* concat the remapped doc number */
            if (doc_num == -1)
                continue;
            if (doc_num > max_doc) 
                CONFESS("doc_num > max_doc: %d %d", doc_num, max_doc);
            doc_num = IntMap_Get(doc_map, doc_num);
            Math_encode_bigend_u32(doc_num, doc_num_buf);
            memcpy(dest, doc_num_buf, DOC_NUM_LEN);
            dest += DOC_NUM_LEN;

            /* concat freq */
            num_bytes = OutStream_encode_vint(freq, dest);
            dest += num_bytes;

            if (store_field_boost) {
                *((u8_t*)dest) = TermDocs_Get_Field_Boost_Byte(term_docs);
                dest++;
            }

            if (store_pos_boost) {
                /* concat the positions and the boosts */
                for (i = 0; i < freq; i++) {
                    const u32_t prox_delta = *positions - last_prox;

                    /* position */
                    dest += OutStream_encode_vint(prox_delta, dest);
                    last_prox = *positions++;

                    /* boost byte */
                    *((u8_t*)dest) = *boosts++;
                    dest++;
                }
            }
            else {
                for (i = 0; i < freq; i++) {
                    const u32_t prox_delta = *positions - last_prox;
                    dest += OutStream_encode_vint(prox_delta, dest);
                    last_prox = *positions++;
                }
            }

            /* concat the term_length */
            memcpy(dest, text_len_buf, TEXT_LEN_LEN);
            dest += TEXT_LEN_LEN;

            /* calc total len */
            posting->len = dest - posting->ptr;

            /* add the posting to the sortpool */
            SortEx_Feed(sort_pool, posting->ptr, posting->len);
        }
    }
    REFCOUNT_DEC(posting);
}

static void 
deserialize(ByteBuf *posting, ViewByteBuf *term_text, ViewByteBuf *positions, 
            i32_t *field_num_ptr, u32_t *doc_num_ptr, u32_t *freq_ptr) 
{
    char    *ptr = posting->ptr;
    size_t   len;

    /* extract field number */
    *field_num_ptr = (i16_t)Math_decode_bigend_u16(ptr);

    /* extract term_text_len, decoding packed 'n', assign term_text */
    ptr += posting->len - TEXT_LEN_LEN;
    term_text->len = Math_decode_bigend_u16(ptr);
    ViewBB_Assign(term_text, posting->ptr + FIELD_NUM_LEN, 
        term_text->len);

    /* extract and assign doc_num, decoding packed 'N' */
    ptr = posting->ptr + FIELD_NUM_LEN + term_text->len + NULL_BYTE_LEN;
    *doc_num_ptr  = Math_decode_bigend_u32(ptr);

    /* move ptr forward */
    ptr = posting->ptr + FIELD_NUM_LEN + term_text->len + NULL_BYTE_LEN 
        + DOC_NUM_LEN;

    /* extract freq and move ptr forward */
    *freq_ptr = InStream_decode_vint(&ptr);

    /* make positions ByteBuf a view of the pos/boost data in the posting */
    len = BBEND(posting) - ptr - TEXT_LEN_LEN;
    ViewBB_Assign(positions, ptr, len);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

