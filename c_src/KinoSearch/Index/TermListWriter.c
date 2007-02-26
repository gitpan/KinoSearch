#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TERMLISTWRITER_VTABLE
#include "KinoSearch/Index/TermListWriter.r"

#include "KinoSearch/InvIndex.r"
#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/Term.h"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/OutStream.r"

/* Open new files for a new field.
 */
static void
init_field(TermListWriter *self, i32_t field_num);

/* Close files, store metadata for a field.
 */
static void
finish_field(TermListWriter *self);

TermListWriter*
TLWriter_new(InvIndex *invindex, SegInfo *seg_info, i32_t is_index, 
             i32_t index_interval, i32_t skip_interval) 
{
    CREATE(self, TermListWriter, TERMLISTWRITER);

    /* assign */
    REFCOUNT_INC(invindex);
    REFCOUNT_INC(seg_info);
    self->invindex       = invindex;
    self->seg_info       = seg_info;
    self->is_index       = is_index;
    self->index_interval = index_interval;
    self->skip_interval  = skip_interval;

    /* init */
    self->fh                 = NULL;
    self->other              = NULL;
    self->last_tl_ptr        = 0;
    self->size               = 0;
    self->last_tinfo         = TInfo_new(I32_MAX,0,0,0,0);
    self->last_text          = BB_new(40);
    self->filename           = BB_new(30);
    self->counts             = Hash_new(0);

    /* create the doppelganger */
    if (!is_index) {
        self->other = TLWriter_new(invindex, seg_info, 1, index_interval,
            skip_interval);
        self->other->other = self;
    }

    return self;
}

void
TLWriter_destroy(TermListWriter *self) 
{
    REFCOUNT_DEC(self->invindex);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->filename);
    REFCOUNT_DEC(self->counts);
    REFCOUNT_DEC(self->fh);
    if (!self->is_index) {
        REFCOUNT_DEC(self->other);
    }
    REFCOUNT_DEC(self->last_text);
    REFCOUNT_DEC(self->last_tinfo);
    free(self);
}

void 
TLWriter_add(TermListWriter* self, ByteBuf* term_text, TermInfo* tinfo) 
{
    OutStream  *fh                 = self->fh;
    TermInfo   *const last_tinfo   = self->last_tinfo;
    char       *term_text_ptr      = term_text->ptr;
    size_t      term_text_len      = term_text->len;
    char       *last_text_ptr      = self->last_text->ptr;
    size_t      last_text_len      = self->last_text->len;
    
    i32_t    overlap;
    char    *diff_start_str;
    size_t   diff_len;

    if (last_tinfo->field_num != tinfo->field_num) {
        if (fh != NULL)
            finish_field(self);
        init_field(self, tinfo->field_num);
        fh = self->fh;
    }

    /* write a subset of the entries to the .tlx index */
    if (    (self->size % self->index_interval == 0)
         && (!self->is_index)               
    ) {
        TLWriter_add(self->other, self->last_text, last_tinfo);
    }

    /* count how many bytes the strings share at the top */ 
    overlap = StrHelp_string_diff(last_text_ptr, term_text_ptr,
        last_text_len, term_text_len);
    diff_start_str = term_text_ptr + overlap;
    diff_len       = term_text_len - overlap;

    /* write number of common bytes and common bytes */
    OutStream_Write_VInt(fh, overlap);
    OutStream_Write_String(fh, diff_start_str, diff_len);
    
    /* write doc_freq */
    OutStream_Write_VInt(fh, tinfo->doc_freq);

    /* delta encode filepointers */
    OutStream_Write_VLong(fh, (tinfo->post_fileptr - last_tinfo->post_fileptr) );

    /* write skipdata */
    if (tinfo->doc_freq >= self->skip_interval)
        OutStream_Write_VInt(fh, tinfo->skip_offset);

    /* the .tlx index file gets a pointer to the location of the primary */
    if (self->is_index) {
        const u64_t tl_ptr = OutStream_STell(self->other->fh);
        OutStream_Write_VLong(self->fh, (tl_ptr - self->last_tl_ptr));
        self->last_tl_ptr = tl_ptr;
    }

    /* track number of terms */
    self->size++;

    /* remember for delta encoding */
    BB_Copy_BB(self->last_text, term_text);
    TInfo_copy(last_tinfo, tinfo);
}

static void
init_field(TermListWriter *self, i32_t field_num)
{
    ByteBuf *filename = self->filename;

    /* build filename */
    BB_Copy_BB(filename, self->seg_info->seg_name);
    if (self->is_index)
        BB_Cat_Str(filename, ".tlx", 4);
    else
        BB_Cat_Str(filename, ".tl", 3);
    BB_Cat_I64(filename, (i64_t)field_num);

    /* open outstream */
    self->fh = Folder_Open_OutStream(self->invindex->folder, filename);

    /* initialize size, TermInfo and last term text */
    self->size = 0;
    TInfo_Reset(self->last_tinfo);
    self->last_tinfo->field_num = field_num;
    self->last_text->len = 0;
}

/* Close files, store metadata for a field.
 */
static void
finish_field(TermListWriter *self)
{
    ByteBuf *field_name = SegInfo_Field_Name(self->seg_info,
        self->last_tinfo->field_num);
    OutStream_SClose(self->fh);
    REFCOUNT_DEC(self->fh);
    self->fh = NULL;
    Hash_Store_I64(self->counts,field_name->ptr, field_name->len,
        (i64_t)self->size);
}

void
TLWriter_finish(TermListWriter *self)
{
    Hash *metadata = Hash_new(0);

    /* close down */
    if (self->fh != NULL)
        finish_field(self);

    if (self->counts->size == 0) {
        /* placeholder */
        Hash_Store_I64(self->counts, "none", 4, 0);
    }

    /* generate metadata */
    Hash_Store_I64(metadata, "format", 6, (i64_t)TERM_LIST_FORMAT);
    Hash_Store_I64(metadata, "size", 4, (i64_t)self->size);
    Hash_Store(metadata, "counts", 6, (Obj*)self->counts);
    Hash_Store_I64(metadata, "index_interval", 14,
        (i64_t)self->index_interval);
    Hash_Store_I64(metadata, "skip_interval", 13, (i64_t)self->skip_interval);

    /* cue the doppelganger's exit and store metadata */
    if (self->is_index) {
        SegInfo_Add_Metadata(self->seg_info, "term_list_index", 15, 
            (Obj*)metadata);
    }
    else {
        TLWriter_Finish(self->other);
        /* store term infos metadata in the segment's metadata hash */
        SegInfo_Add_Metadata(self->seg_info, "term_list", 9, 
            (Obj*)metadata);
    }

    /* clean up, now that seg_info owns a refcount */
    REFCOUNT_DEC(metadata);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

