#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_SEGPOSTINGLIST_VTABLE
#include "KinoSearch/Index/SegPostingList.r"

#include "KinoSearch/Posting.r"
#include "KinoSearch/Schema.r"
#include "KinoSearch/Schema/FieldSpec.r"
#include "KinoSearch/Index/DelDocs.r"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/SkipStepper.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/TermInfo.r"
#include "KinoSearch/Index/SegLexicon.r"
#include "KinoSearch/Index/LexReader.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/Folder.r"

/* Low level seek call. 
 */
static void
seek_tinfo(SegPostingList *self, TermInfo *tinfo);

SegPostingList*
SegPList_new(Schema *schema, Folder *folder, SegInfo *seg_info, 
             const ByteBuf *field, LexReader *lex_reader, 
             DelDocs *deldocs, u32_t skip_interval) 
{
    ByteBuf *post_filename;
    CREATE(self, SegPostingList, SEGPOSTINGLIST);

    /* init */
    self->doc_freq        = DOC_NUM_SENTINEL;
    self->post_stream     = NULL;
    self->count           = 0;
    self->doc_base        = 0;

    /* init skipping vars */
    self->skip_stepper    = SkipStepper_new();
    self->skip_count      = 0;
    self->num_skips       = 0;
    self->skip_stream     = NULL;

    /* assign */
    REFCOUNT_INC(schema);
    REFCOUNT_INC(folder);
    REFCOUNT_INC(seg_info);
    if (deldocs != NULL)
        REFCOUNT_INC(deldocs);
    REFCOUNT_INC(lex_reader);
    self->schema          = schema;
    self->folder          = folder;
    self->seg_info        = seg_info;
    self->field           = BB_CLONE(field);
    self->deldocs         = deldocs;
    self->lex_reader      = lex_reader;
    self->skip_interval   = skip_interval;
    
    /* derive */
    self->posting   = Schema_Fetch_Posting(schema, field);
    self->field_num = SegInfo_Field_Num(seg_info, field);

    /* build the filename of the postings file */
    post_filename = BB_CLONE(seg_info->seg_name);
    BB_Cat_Str(post_filename, ".p", 2);
    BB_Cat_I64(post_filename, (i64_t)self->field_num);

    /* open both a main stream and a skip stream if the field exists */
    if (Folder_File_Exists(self->folder, post_filename)) {
        ByteBuf *skip_filename = BB_CLONE(seg_info->seg_name);
        
        /* skip_stream */
        BB_Cat_Str(skip_filename, ".skip", 5);
        self->skip_stream = Folder_Open_InStream(self->folder, skip_filename);
        REFCOUNT_DEC(skip_filename);

        /* main stream */
        self->post_stream = Folder_Open_InStream(self->folder, post_filename);
    }
    else {
        /*  empty, so don't bother with these */
        self->post_stream = NULL;
        self->skip_stream = NULL;
    }

    /* clean up */
    REFCOUNT_DEC(post_filename);

    return self;
}

void 
SegPList_destroy(SegPostingList *self)
{
    REFCOUNT_DEC(self->schema);
    REFCOUNT_DEC(self->folder);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->posting);
    REFCOUNT_DEC(self->skip_stepper);
    REFCOUNT_DEC(self->field);
    REFCOUNT_DEC(self->deldocs);
    REFCOUNT_DEC(self->lex_reader);
    
    if (self->post_stream != NULL) {
        InStream_SClose(self->post_stream);
        InStream_SClose(self->skip_stream);
        REFCOUNT_DEC(self->post_stream);
        REFCOUNT_DEC(self->skip_stream);
    }

    free(self);
}

Posting*
SegPList_get_posting(SegPostingList *self) 
{
    return self->posting;
}

u32_t
SegPList_get_doc_freq(SegPostingList *self) 
{
    return self->doc_freq;
}

u32_t
SegPList_get_doc_num(SegPostingList *self) 
{
    return self->posting->doc_num;
}

/* TODO: This is unsafe to call except right after constructor. */
void
SegPList_set_doc_base(SegPostingList *self, u32_t doc_base)
{
    self->doc_base = doc_base;
}

u32_t 
SegPList_bulk_read(SegPostingList *self, ByteBuf *postings, 
                      u32_t num_wanted)
{
    u32_t num_got = 0;
    InStream *const post_stream = self->post_stream;
    DelDocs  *const deldocs     = self->deldocs;
    Posting  *const posting     = self->posting;
    const u32_t     doc_base    = self->doc_base;

    /* cap num_wanted by how many we can supply at maximum */
    if (num_wanted > self->doc_freq - self->count)
        num_wanted = self->doc_freq - self->count;

    do {
        Posting *temp;

        /* do a raw read */
        num_got = Post_Bulk_Read(posting, post_stream, postings, num_wanted); 
        self->count += num_got;

        /* if no deldocs, no need to process deletions */
        if (deldocs == NULL)
            break;

        /* process deletions by splicing them out of linked list */
        temp = (Posting*)postings->ptr;
        while (temp != NULL) {
            Posting *next = temp->next;
            while (next != NULL) {
                const u32_t doc_minus_base = next->doc_num - doc_base;
                if (!DelDocs_Get(deldocs, doc_minus_base))
                    break;
                next = next->next;
                num_got--;
            }
            temp->next = next;
            temp = next;
        }

    /* only loop again if all docs found were deleted and we have more */
    } while (num_got == 0 && self->count < self->doc_freq);

    return num_got;
}

bool_t
SegPList_next(SegPostingList *self) 
{
    InStream *const post_stream = self->post_stream;
    DelDocs  *const deldocs     = self->deldocs;
    Posting  *const posting     = self->posting;

    while (1) {

        /* bail if we're out of docs */
        if (self->count >= self->doc_freq) {
            Post_Reset(posting, self->doc_base);
            return false;
        }
        self->count++;

        Post_Read_Record(posting, post_stream);

        /* if the doc isn't deleted... success! */
        if (deldocs == NULL) {
            break;
        }
        else {
            const u32_t doc_minus_base = posting->doc_num - self->doc_base;
            if ( !DelDocs_Get(deldocs, doc_minus_base) ) {
                break;
            }
        }
    }

    return true;
}

bool_t
SegPList_skip_to(SegPostingList *self, u32_t target)
{
    Posting *posting = self->posting;

    if (self->doc_freq >= self->skip_interval) {
        InStream *post_stream           = self->post_stream;
        InStream *skip_stream           = self->skip_stream;
        SkipStepper *const skip_stepper = self->skip_stepper;
        u32_t new_doc_num               = skip_stepper->doc_num;
        u64_t new_filepos               = InStream_STell(post_stream);

        /* Assuming the default skip_interval of 16...
         * 
         * Say we're currently on the 5th doc matching this term, and we get a
         * request to skip to the 18th doc matching it.  We won't have skipped
         * yet, but we'll have already gone past 5 of the 16 skip docs --
         * ergo, the modulus in the following formula.
         */
        i32_t num_skipped = 0 - (self->count % self->skip_interval);

        /* see if there's anything to skip */
        while (target > skip_stepper->doc_num) {
            new_doc_num   = skip_stepper->doc_num;
            new_filepos   = skip_stepper->filepos;

            if (   skip_stepper->doc_num != self->doc_base 
                && skip_stepper->doc_num >= posting->doc_num
            ) {
                num_skipped += self->skip_interval;
            }

            if (self->skip_count >= self->num_skips)
                break;

            SkipStepper_Read_Record(skip_stepper, skip_stream);
            self->skip_count++;
        }

        /* if we found something to skip, skip it */
        if (new_filepos > InStream_STell(post_stream)) {

            /* move the postings filepointer up */
            InStream_SSeek(post_stream, new_filepos);

            /* jump to the new doc num */
            posting->doc_num = new_doc_num;

            /* increase count by the number of docs we skipped over */
            self->count += num_skipped;
        }
    }

    /* done skipping, so scan */
    do {
        if (!SegPList_Next(self)) {
            return false;
        }
    } while (target > posting->doc_num);
    return true;
}

void
SegPList_seek(SegPostingList *self, Term *target)
{
    TermInfo *tinfo = LexReader_Fetch_Term_Info(self->lex_reader, target);
    seek_tinfo(self, tinfo);
}

void
SegPList_seek_lex(SegPostingList *self, Lexicon *lexicon)
{
    /* maybe true, maybe not */
    SegLexicon *const seg_lexicon = (SegLexicon*)lexicon;

    /* optimized case */
    if (   OBJ_IS_A(lexicon, SEGLEXICON)
        && seg_lexicon->seg_info == self->seg_info /* i.e. same segment */
    ) {
        seek_tinfo(self, SegLex_Get_Term_Info(seg_lexicon));
    }
    /* punt case */
    else {
        SegPList_Seek(self, Lex_Get_Term(lexicon));
    }
}

static void
seek_tinfo(SegPostingList *self, TermInfo *tinfo) 
{
    self->count = 0;

    if (tinfo == NULL) {
        /* Next will return false; other methods invalid now */
        self->doc_freq = 0;
    }
    else {
        /* transfer doc_freq, seek main stream */
        self->doc_freq     = tinfo->doc_freq;
        InStream_SSeek(self->post_stream, tinfo->post_filepos);

        /* prepare posting */
        Post_Reset(self->posting, self->doc_base);

        /* prepare to skip */
        self->skip_count       = 0;
        self->num_skips        = tinfo->doc_freq / self->skip_interval;
        SkipStepper_Reset(self->skip_stepper, self->doc_base,
            (u64_t)tinfo->post_filepos);
        InStream_SSeek(self->skip_stream, tinfo->skip_filepos);
    }
}

struct kino_Scorer*
SegPList_make_scorer(SegPostingList *self, struct kino_Similarity *sim, 
                     void *weight, float weight_val)
{
    return Post_Make_Scorer(self->posting, sim, (PostingList*)self, 
        weight, weight_val);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */


