#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SEGTERMLIST_VTABLE
#include "KinoSearch/Index/SegTermList.r"

#include "KinoSearch/Schema.r"
#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermDocs.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Index/SegTermListCache.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Util/IntMap.r"

/* Iterate until the state is greater than or equal to [term].
 */
static void
scan_to(SegTermList *self, Term *term);

/* Read in a term's worth of data from the input stream.
 */
static void
read_term_text(SegTermList *self);

/* Read in a TermInfo from the input stream.
 */
static void
read_tinfo(SegTermList *self);

SegTermList*
SegTermList_new(Schema *schema, Folder *folder, SegInfo *seg_info, 
                const ByteBuf *field, SegTermListCache *tl_cache, 
                bool_t is_index) 
{
    char *metadata_key = is_index ? "term_list_index" : "term_list";
    Hash *metadata = (Hash*)SegInfo_Extract_Metadata(seg_info, metadata_key,
        strlen(metadata_key));
    Hash *counts = (Hash*)Hash_Fetch(metadata, "counts", 6);
    ByteBuf *filename = BB_new(30);
    CREATE(self, SegTermList, SEGTERMLIST);

    /* derive */
    self->field_num      = SegInfo_Field_Num(seg_info, field);

    /* init */
    self->tinfo          = TInfo_new(self->field_num,0,0,0,0);
    self->term           = NULL;

    /* assign */
    self->is_index       = is_index;
    self->field          = BB_CLONE(field);
    REFCOUNT_INC(schema);
    REFCOUNT_INC(folder);
    REFCOUNT_INC(seg_info);
    self->schema         = schema;
    self->folder         = folder;
    self->seg_info       = seg_info;

    /* cache can be null, if this enum is being used to fill a cache */
    if (tl_cache != NULL)
        REFCOUNT_INC(tl_cache);
    self->tl_cache = tl_cache;

    /* open instream */
    BB_Cat_BB(filename, seg_info->seg_name);
    if (is_index)
        BB_Cat_Str(filename, ".tlx", 4);
    else
        BB_Cat_Str(filename, ".tl", 3);
    BB_Cat_I64(filename, (i64_t)self->field_num);
    self->instream = Folder_Open_InStream(folder, filename);
    REFCOUNT_DEC(filename);

    /* check format */
    if (Hash_Fetch_I64(metadata, "format", 6) > TERM_LIST_FORMAT ) {
        CONFESS("Unsupported term list format: %d",
            Hash_Fetch_I64(metadata, "format", 6));
    }

    /* extract some vars from the seg_info's metadata */
    if (counts == NULL)
        CONFESS("Failed to extract 'counts' from '%s'", metadata_key);
    self->size = Hash_Fetch_I64(counts, field->ptr, field->len);
    self->index_interval = Hash_Fetch_I64(metadata, "index_interval", 14);
    self->skip_interval  = Hash_Fetch_I64(metadata, "skip_interval", 13);

    /* define the term_num of the Enum as "not yet started" */
    self->term_num = -1;

    return self;
}

void
SegTermList_destroy(SegTermList *self) 
{
    REFCOUNT_DEC(self->schema);
    REFCOUNT_DEC(self->folder);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->term);
    REFCOUNT_DEC(self->field);
    REFCOUNT_DEC(self->tl_cache);
    REFCOUNT_DEC(self->instream);
    REFCOUNT_DEC(self->tinfo);
    free(self);
}

void
SegTermList_seek(SegTermList *self, Term *term)
{
    SegTermListCache *const tl_cache = self->tl_cache;
    if (tl_cache == NULL)
        CONFESS("Can't seek - SegTermListCache is NULL");

    /* reset upon null term */
    if (term == NULL) {
        SegTermList_Reset(self);
        return;
    }
    /* verify field */
    else if ( BB_compare(&(self->field), &(term->field)) != 0 ) {
        CONFESS("Wrong field: '%s', '%s'", term->field, self->field);
    }

    /* begin transaction */
    SegTLCache_Lock(tl_cache);

    /* use the cache to get into the ballpark */
    SegTLCache_Seek(tl_cache, term);
    TInfo_Copy(self->tinfo, SegTLCache_Get_Term_Info(tl_cache));
    self->term_num = SegTLCache_Get_Term_Num(tl_cache);
    if (self->term == NULL)
        self->term = (Term*)Term_Clone( SegTLCache_Get_Term(tl_cache) );
    else 
        Term_Copy(self->term, SegTLCache_Get_Term(tl_cache));
    InStream_SSeek(self->instream, self->tinfo->index_fileptr);

    /* end transaction */
    SegTLCache_Unlock(tl_cache);

    /* scan to get to the precise location */
    scan_to(self, term);
}

SegTermList*
SegTermList_clone(SegTermList *self)
{
    SegTermList *evil_twin = SegTermList_new(self->schema, self->folder,
        self->seg_info, self->field, self->tl_cache, self->is_index);

    /* sync the clone's state */
    InStream_SSeek(evil_twin->instream, InStream_STell(self->instream));
    evil_twin->term_num = self->term_num;
    if (self->term != NULL)
        evil_twin->term = (Term*)Term_Clone(SegTermList_Get_Term(self) );
    TInfo_Copy(evil_twin->tinfo, self->tinfo);

    return evil_twin;
}

void
SegTermList_reset(SegTermList* self) 
{
    self->term_num = -1;
    InStream_SSeek(self->instream, 0);
    REFCOUNT_DEC(self->term);
    self->term = NULL;
    TInfo_Reset(self->tinfo);
    self->tinfo->field_num = self->field_num;
}

i32_t
SegTermList_get_field_num(SegTermList *self)
{
    return self->tinfo->field_num;
}

i32_t
SegTermList_get_term_num(SegTermList *self)
{
    return self->term_num;
}

Term*
SegTermList_get_term(SegTermList *self)
{
    return self->term;
}

TermInfo*
SegTermList_get_term_info(SegTermList *self)
{
    return self->tinfo;
}

bool_t 
SegTermList_next(SegTermList *self) 
{
    /* if we've run out of terms, null out and return */
    if (++self->term_num >= self->size) {
        self->term_num = self->size; /* don't keep growing */
        REFCOUNT_DEC(self->term);
        self->term = NULL;
        return false;
    }

    /* read next term/terminfo */
    read_term_text(self);
    read_tinfo(self);

    return true;
}

static void
read_term_text(SegTermList *self)
{
    InStream *const instream = self->instream;
    const i32_t text_overlap     = InStream_Read_VInt(instream);
    const i32_t finish_chars_len = InStream_Read_VInt(instream);
    const i32_t total_text_len   = text_overlap + finish_chars_len;
    ByteBuf *term_text;

    /* get the term's text buffer and allocate space */
    if (self->term == NULL) {
        ByteBuf empty = BYTEBUF_BLANK;
        ByteBuf *const field_name 
            = SegInfo_Field_Name(self->seg_info, self->field_num);
        self->term = Term_new(field_name, &empty);
    }
    term_text = self->term->text;
    BB_Grow(term_text, total_text_len);

    /* set the term text */
    term_text->len = total_text_len;
    InStream_Read_Chars(instream, term_text->ptr, text_overlap,
        finish_chars_len);

    /* null-terminate */
    *(term_text->ptr + total_text_len) = '\0';
}

void
read_tinfo(SegTermList *self)
{
    InStream   *const instream   = self->instream;
    TermInfo   *const tinfo      = self->tinfo;

    /* read doc freq */
    tinfo->doc_freq = InStream_Read_VInt(instream);

    /* adjust file pointer. */
    tinfo->post_fileptr += InStream_Read_VLong(instream);

    /* read skip data */
    if (tinfo->doc_freq >= self->skip_interval)
        tinfo->skip_offset = InStream_Read_VInt(instream);
    else
        tinfo->skip_offset = 0;

    /* read filepointer to main enum if this is an index enum */
    if (self->is_index)
        tinfo->index_fileptr += InStream_Read_VLong(instream);
}

static void
scan_to(SegTermList *self, Term *term)
{
    ByteBuf    *const target        = term->text;
    ByteBuf    *const current_text  = self->term->text;

    /* keep looping until the term text is lexically ge target */
    do {
        const i32_t comparison = BB_compare(&current_text, &target);
        if ( comparison >= 0 &&  self->term_num != -1) {
            break;
        }
    } while (SegTermList_Next(self));
}

IntMap*
SegTermList_build_sort_cache(SegTermList *self, TermDocs *term_docs, 
                             u32_t max_doc)
{
    i32_t *ints = CALLOCATE(max_doc, i32_t);
    i32_t term_num = 0;

    SegTermList_Reset(self);

    while (SegTermList_Next(self)) {
        TermDocs_Seek_TL(term_docs, (TermList*)self);
            
        /* assign the same sort position to all docs with this term */
        while (TermDocs_Next(term_docs)) {
            ints[ TermDocs_Get_Doc(term_docs) ] = term_num;
        }
        term_num++;
    }

    return IntMap_new(ints, max_doc);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

