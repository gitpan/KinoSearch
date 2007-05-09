#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_LEXWRITER_VTABLE
#include "KinoSearch/Index/LexWriter.r"

#include "KinoSearch/Schema.r"
#include "KinoSearch/InvIndex.r"
#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermStepper.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/OutStream.r"

LexWriter*
LexWriter_new(InvIndex *invindex, SegInfo *seg_info, i32_t is_index) 
{
    ByteBuf empty = BYTEBUF_BLANK;
    CREATE(self, LexWriter, LEXWRITER);

    /* assign */
    REFCOUNT_INC(invindex);
    REFCOUNT_INC(seg_info);
    self->invindex       = invindex;
    self->seg_info       = seg_info;
    self->is_index       = is_index;
    self->index_interval = invindex->schema->index_interval;
    self->skip_interval  = invindex->schema->skip_interval;

    /* init */
    self->outstream          = NULL;
    self->other              = NULL;
    self->last_lex_filepos       = 0;
    self->count              = 0;
    self->last_tinfo         = TInfo_new(0,0,0,0);
    self->last_text          = BB_new(40);
    self->filename           = BB_new(30);
    self->counts             = Hash_new(0);
    self->stepper            = TermStepper_new(&empty, self->skip_interval,
                                    is_index);
    self->temp_mode          = false;

    /* create the doppelganger */
    if (!is_index) {
        self->other = LexWriter_new(invindex, seg_info, true);
        self->other->other = self;
    }

    return self;
}

void
LexWriter_destroy(LexWriter *self) 
{
    REFCOUNT_DEC(self->invindex);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->stepper);
    REFCOUNT_DEC(self->filename);
    REFCOUNT_DEC(self->counts);
    REFCOUNT_DEC(self->outstream);
    if (!self->is_index) {
        REFCOUNT_DEC(self->other);
    }
    REFCOUNT_DEC(self->last_text);
    REFCOUNT_DEC(self->last_tinfo);
    free(self);
}

void 
LexWriter_add(LexWriter* self, ByteBuf* term_text, TermInfo* tinfo) 
{
    /* the .lexx index file gets a pointer to the location of the primary */
    const u64_t lex_filepos = self->is_index
        ? OutStream_STell(self->other->outstream)
        : 0;

    /* write a subset of the entries to the .lexx index */
    if (    (self->count % self->index_interval == 0)
         && !self->is_index
         && !self->temp_mode
    ) {
        LexWriter_add(self->other, self->last_text, 
            self->last_tinfo);
    }

    /* write the record; track number of terms */
    TermStepper_Write_Record(self->stepper, self->outstream, 
        term_text->ptr, term_text->len, 
        self->last_text->ptr, self->last_text->len, 
        tinfo, self->last_tinfo, 
        lex_filepos, self->last_lex_filepos
    );
    self->count++;

    /* remember for delta encoding */
    BB_Copy_BB(self->last_text, term_text);
    TInfo_copy(self->last_tinfo, tinfo);
    self->last_lex_filepos = lex_filepos;
}

void
LexWriter_start_field(LexWriter *self, i32_t field_num)
{
    ByteBuf *filename = self->filename;

    /* build filename */
    BB_Copy_BB(filename, self->seg_info->seg_name);
    if (self->is_index)
        BB_Cat_Str(filename, ".lexx", 5);
    else
        BB_Cat_Str(filename, ".lex", 4);
    BB_Cat_I64(filename, (i64_t)field_num);

    /* open outstream */
    self->outstream = Folder_Open_OutStream(self->invindex->folder, filename);

    /* initialize count, TermInfo and last term text */
    self->count = 0;
    TInfo_Reset(self->last_tinfo);
    self->last_text->len = 0;
    self->last_lex_filepos = 0;

    /* switch over other */
    if (!self->is_index)
        LexWriter_Start_Field(self->other, field_num);
}

void
LexWriter_finish_field(LexWriter *self, i32_t field_num)
{
    ByteBuf *field_name = SegInfo_Field_Name(self->seg_info, field_num);
    OutStream_SClose(self->outstream);
    REFCOUNT_DEC(self->outstream);
    self->outstream = NULL;
    Hash_Store_I64(self->counts,field_name->ptr, field_name->len,
        (i64_t)self->count);

    /* finish other */
    if (!self->is_index)
        LexWriter_Finish_Field(self->other, field_num);
}

void
LexWriter_enter_temp_mode(LexWriter *self, OutStream *temp_outstream)
{
    /* assign outstream */
    if (self->outstream != NULL)
        CONFESS("Can't enter temp mode (filename: %s) ", self->filename->ptr);
    REFCOUNT_INC(temp_outstream);
    self->outstream = temp_outstream;

    /* initialize count, TermInfo and last term text */
    self->count = 0;
    TInfo_Reset(self->last_tinfo);
    self->last_text->len = 0;
    self->last_lex_filepos = 0;

    /* remember that we're in temp mode */
    self->temp_mode = true;
}

void
LexWriter_leave_temp_mode(LexWriter *self)
{
    REFCOUNT_DEC(self->outstream);
    self->outstream = NULL;
    self->temp_mode = false;
}

void
LexWriter_finish(LexWriter *self)
{
    Hash *metadata = Hash_new(0);

    /* close down */
    if (self->outstream != NULL)
        CONFESS("File '%s' never closed", self->filename->ptr);

    if (self->counts->size == 0) {
        /* placeholder */
        Hash_Store_I64(self->counts, "none", 4, 0);
    }

    /* generate metadata */
    Hash_Store_I64(metadata, "format", 6, (i64_t)LEXICON_FORMAT);
    Hash_Store(metadata, "counts", 6, (Obj*)self->counts);

    /* cue the doppelganger's exit and store metadata */
    if (self->is_index) {
        SegInfo_Add_Metadata(self->seg_info, "lexicon_index", 13, 
            (Obj*)metadata);
    }
    else {
        LexWriter_Finish(self->other);
        /* store term infos metadata in the segment's metadata hash */
        SegInfo_Add_Metadata(self->seg_info, "lexicon", 7, (Obj*)metadata);
    }

    /* clean up, now that seg_info owns a refcount */
    REFCOUNT_DEC(metadata);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

