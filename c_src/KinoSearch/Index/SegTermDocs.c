#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SEGTERMDOCS_VTABLE
#include "KinoSearch/Index/SegTermDocs.r"

#include "KinoSearch/Schema.r"
#include "KinoSearch/Schema/FieldSpec.r"
#include "KinoSearch/Index/DelDocs.r"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Index/SegTermList.r"
#include "KinoSearch/Index/TermListReader.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/Folder.r"

/* Low level seek call. 
 */
static void
seek_tinfo(SegTermDocs *self, TermInfo *tinfo);

SegTermDocs*
SegTermDocs_new(Schema *schema, Folder *folder, SegInfo *seg_info, 
                TermListReader *tl_reader, DelDocs *deldocs, 
                u32_t skip_interval) 
{
    CREATE(self, SegTermDocs, SEGTERMDOCS);

    /* self->positions and self->boosts start life as empty strings */
    self->positions     = BB_new(0);
    self->boosts        = BB_new(0);

    /* more init */
    self->field_num       = I32_MAX;
    self->fspec           = NULL;
    self->count           = 0;
    self->doc_freq        = KINO_TERM_DOCS_SENTINEL;
    self->doc             = KINO_TERM_DOCS_SENTINEL;
    self->freq            = KINO_TERM_DOCS_SENTINEL;
    self->field_boost_byte = 0;
    self->skip_doc        = 0;
    self->skip_count      = 0;
    self->num_skips       = 0;
    self->post_stream     = NULL;
    self->skip_stream     = NULL;
    self->have_skipped    = false;
    self->post_fileptr    = 0;
    self->skip_fileptr    = 0;

    /* assign */
    REFCOUNT_INC(schema);
    REFCOUNT_INC(folder);
    REFCOUNT_INC(seg_info);
    REFCOUNT_INC(deldocs);
    REFCOUNT_INC(tl_reader);
    self->schema          = schema;
    self->folder          = folder;
    self->seg_info        = seg_info;
    self->deldocs         = deldocs;
    self->tl_reader       = tl_reader;
    self->skip_interval   = skip_interval;

    return self;
}

void 
SegTermDocs_destroy(SegTermDocs *self)
{
    REFCOUNT_DEC(self->schema);
    REFCOUNT_DEC(self->folder);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->deldocs);
    REFCOUNT_DEC(self->tl_reader);
    REFCOUNT_DEC(self->positions);
    REFCOUNT_DEC(self->boosts);
    
    if (self->post_stream != NULL) {
        InStream_SClose(self->post_stream);
        InStream_SClose(self->skip_stream);
        REFCOUNT_DEC(self->post_stream);
        REFCOUNT_DEC(self->skip_stream);
    }

    free(self);
}

void
SegTermDocs_set_doc_freq(SegTermDocs *self, u32_t doc_freq) 
{
    self->doc_freq = doc_freq;
}

u32_t
SegTermDocs_get_doc_freq(SegTermDocs *self) 
{
    return self->doc_freq;
}

u32_t
SegTermDocs_get_doc(SegTermDocs *self) 
{
    return self->doc;
}

u32_t
SegTermDocs_get_freq(SegTermDocs *self) 
{
    return self->freq;
}

u8_t 
SegTermDocs_get_field_boost_byte(SegTermDocs *self)
{
    return self->field_boost_byte;
}

ByteBuf*
SegTermDocs_get_positions(SegTermDocs *self) 
{
    return self->positions;
}

ByteBuf*
SegTermDocs_get_boosts(SegTermDocs *self) 
{
    return self->boosts;
}

u32_t 
SegTermDocs_bulk_read(SegTermDocs *self, ByteBuf *doc_nums_bb, 
                      ByteBuf *field_boosts_bb, ByteBuf *freqs_bb, 
                      ByteBuf *prox_bb, ByteBuf *boosts_bb, u32_t num_wanted)
{
    const size_t   len          = num_wanted * sizeof(u32_t);
    u32_t         *doc_nums;
    u32_t         *freqs;
    u8_t          *field_boost_bytes;
    u32_t          num_got = 0;
    const bool_t   store_field_boost = self->fspec == NULL 
                        ? false
                        : self->fspec->store_field_boost;

    /* allocate space in supplied ByteBufs, if necessary */ 
    BB_Grow(doc_nums_bb, len);
    BB_Grow(freqs_bb, len);
    if (store_field_boost)
        BB_Grow(field_boosts_bb, num_wanted);
    boosts_bb->len = 0;
    doc_nums = (u32_t*)doc_nums_bb->ptr;
    freqs    = (u32_t*)freqs_bb->ptr;
    field_boost_bytes = (u8_t*)field_boosts_bb->ptr;

    while (num_got < num_wanted && TermDocs_Next(self)) {
        *doc_nums++ = self->doc;
        *freqs++    = self->freq;
        if (store_field_boost)
            *field_boost_bytes++ = self->field_boost_byte;
        BB_Cat_BB(boosts_bb, self->boosts);
        BB_Cat_BB(prox_bb,   self->positions);
        num_got++;
    }

    /* set the string ends */
    doc_nums_bb->len = (num_got * sizeof(u32_t));
    freqs_bb->len    = (num_got * sizeof(u32_t));
    if (store_field_boost)
        field_boosts_bb->len = num_got;

    return num_got;
}

bool_t
SegTermDocs_next(SegTermDocs *self) 
{
    InStream *post_stream = self->post_stream;
    DelDocs  *deldocs     = self->deldocs;

    while (1) {
        size_t len;
        u32_t  doc_code;
        u32_t  num_pos_to_read = 0;
        u32_t  position = 0; 
        u32_t *positions;
        u8_t  *boosts;

        /* bail if we're out of docs */
        if (self->count == self->doc_freq) {
            return false;
        }

        /* decode delta doc */
        doc_code = InStream_Read_VInt(post_stream);
        self->doc  += doc_code >> 1;

        /* if the stored num was odd, the freq is 1 */ 
        if (doc_code & 1) {
            self->freq = 1;
        }
        /* otherwise, freq was stored as a VInt. */
        else {
            self->freq = InStream_Read_VInt(post_stream);
        } 

        self->count++;

        if (self->fspec->store_field_boost)
            self->field_boost_byte = InStream_Read_Byte(post_stream);
        
        /* store positions and boosts */
        num_pos_to_read = self->freq;
        len = num_pos_to_read * sizeof(u32_t);
        BB_Grow( self->positions, len );
        self->positions->len = len;
        positions = (u32_t*)self->positions->ptr;

        if (self->fspec->store_pos_boost) {
            BB_Grow( self->boosts, num_pos_to_read );
            self->boosts->len = num_pos_to_read;
            boosts  = (u8_t*)self->boosts->ptr;

            while (num_pos_to_read--) {
                position += InStream_Read_VInt(post_stream);
                *positions++ = position;
                *boosts++ = InStream_Read_Byte(post_stream); 
            }

        }
        else {
            while (num_pos_to_read--) {
                position += InStream_Read_VInt(post_stream);
                *positions++ = position;
            }
        }

        
        /* if the doc isn't deleted... success! */
        if (!DelDocs_Get(deldocs, self->doc))
            break;
    }

    return true;
}

bool_t
SegTermDocs_skip_to(SegTermDocs *self, u32_t target) 
{
    if (self->doc_freq >= self->skip_interval) {
        InStream *post_stream   = self->post_stream;
        InStream *skip_stream   = self->skip_stream;
        u32_t last_skip_doc     = self->skip_doc;
        u64_t last_post_fileptr = InStream_STell(post_stream);
        i32_t num_skipped       = -1 - (self->count % self->skip_interval);

        if (!self->have_skipped) {
            InStream_SSeek(self->skip_stream, self->skip_fileptr);
            self->have_skipped = true;
        }
        
        while (target > self->skip_doc) {
            last_skip_doc     = self->skip_doc;
            last_post_fileptr = self->post_fileptr;

            if (self->skip_doc != 0 && self->skip_doc >= self->doc) {
                num_skipped += self->skip_interval;
            }

            if (self->skip_count >= self->num_skips) {
                break;
            }

            self->skip_doc     += InStream_Read_VInt(skip_stream);
            self->post_fileptr += InStream_Read_VInt(skip_stream);

            self->skip_count++;
        }

        /* if there's something to skip, skip it */
        if (last_post_fileptr > InStream_STell(post_stream)) {
            InStream_SSeek(post_stream, last_post_fileptr);
            self->doc = last_skip_doc;
            self->count += num_skipped;
        }
    }

    /* done skipping, so scan */
    do {
        if (!TermDocs_Next(self)) {
            return false;
        }
    } while (target > self->doc);
    return true;
}

void
SegTermDocs_seek(SegTermDocs *self, Term *target)
{
    TermInfo *tinfo = TLReader_Fetch_Term_Info(self->tl_reader, target);
    seek_tinfo(self, tinfo);
}

void
SegTermDocs_seek_tl(SegTermDocs *self, TermList *term_list)
{
    /* maybe true, maybe not */
    SegTermList *const seg_term_list = (SegTermList*)term_list;

    /* optimized case */
    if (   OBJ_IS_A(term_list, SEGTERMLIST)
        && seg_term_list->seg_info == self->seg_info /* i.e. same segment */
    ) {
        seek_tinfo(self, SegTermList_Get_Term_Info(seg_term_list));
    }
    /* punt case */
    else {
        SegTermDocs_Seek(self, TermList_Get_Term(term_list));
    }
}

static void
seek_tinfo(SegTermDocs *self, TermInfo *tinfo) 
{
    self->count = 0;

    if (tinfo == NULL) {
        self->doc_freq = 0;
    }
    else {
        if (self->field_num != tinfo->field_num) {
            ByteBuf *field_name 
                = SegInfo_Field_Name(self->seg_info, tinfo->field_num);
            ByteBuf *filename = BB_CLONE(self->seg_info->seg_name);

            /* get the FieldSpec */
            self->fspec = Schema_Fetch_FSpec(self->schema, field_name);

            /* build the filename of the postings file */
            BB_Cat_Str(filename, ".p", 2);
            BB_Cat_I64(filename, (i64_t)tinfo->field_num);

            /* close down any existing streams */
            if (self->post_stream != NULL) {
                InStream_SClose(self->post_stream);
                InStream_SClose(self->skip_stream);
                REFCOUNT_DEC(self->post_stream);
                REFCOUNT_DEC(self->skip_stream);
            }

            /* open both a main stream and a skip_stream dupe */
            self->post_stream = Folder_Open_InStream(self->folder, filename);
            self->skip_stream = (InStream*)Obj_Clone(self->post_stream);
            self->field_num = tinfo->field_num;

            /* clean up */
            REFCOUNT_DEC(filename);
        }
        self->doc          = 0;
        self->freq         = 0;
        self->field_boost_byte = 0;
        self->skip_doc     = 0;
        self->skip_count   = 0;
        self->have_skipped = false;
        self->num_skips    = tinfo->doc_freq / self->skip_interval;
        self->doc_freq     = tinfo->doc_freq;
        self->post_fileptr = tinfo->post_fileptr;
        self->skip_fileptr = tinfo->post_fileptr + tinfo->skip_offset;
        InStream_SSeek( self->post_stream, tinfo->post_fileptr );
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

