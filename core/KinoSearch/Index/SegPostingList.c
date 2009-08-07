#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SegPostingList.h"
#include "KinoSearch/Architecture.h"
#include "KinoSearch/Posting.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/PostingsReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SkipStepper.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Index/SegLexicon.h"
#include "KinoSearch/Index/LexiconReader.h"
#include "KinoSearch/Posting/RawPosting.h"
#include "KinoSearch/Search/Compiler.h"
#include "KinoSearch/Search/Matcher.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/MemoryPool.h"

/* Low level seek call. 
 */
static void
S_seek_tinfo(SegPostingList *self, TermInfo *tinfo);

SegPostingList*
SegPList_new(PostingsReader *postings_reader, const CharBuf *field)
{
    SegPostingList *self = (SegPostingList*)VTable_Make_Obj(SEGPOSTINGLIST);
    return SegPList_init(self, postings_reader, field);
}

SegPostingList*
SegPList_init(SegPostingList *self, PostingsReader *postings_reader, 
              const CharBuf *field)
{
    Schema       *const schema   = PostReader_Get_Schema(postings_reader);
    Folder       *const folder   = PostReader_Get_Folder(postings_reader);
    Segment      *const segment  = PostReader_Get_Segment(postings_reader);
    Architecture *const arch     = Schema_Get_Architecture(schema);
    CharBuf      *const seg_name = Seg_Get_Name(segment);
    i32_t         field_num      = Seg_Field_Num(segment, field);
    CharBuf      *post_file      = CB_newf("%o/postings-%i32.dat", 
                                           seg_name, field_num);
    CharBuf      *skip_file      = CB_newf("%o/postings.skip", seg_name);

    /* Init. */
    self->doc_freq        = 0;
    self->count           = 0;
    self->doc_base        = 0;

    /* Init skipping vars. */
    self->skip_stepper    = SkipStepper_new();
    self->skip_count      = 0;
    self->num_skips       = 0;

    /* Assign. */
    self->post_reader     = (PostingsReader*)INCREF(postings_reader);
    self->field           = CB_Clone(field);
    self->skip_interval   = Arch_Skip_Interval(arch);
    
    /* Derive. */
    self->posting   = Schema_Fetch_Posting(schema, field);
    self->posting   = (Posting*)Post_Clone(self->posting);
    self->field_num = field_num;

    /* Open both a main stream and a skip stream if the field exists. */
    if (Folder_Exists(folder, post_file)) {
        self->post_stream = Folder_Open_In(folder, post_file);
        self->skip_stream = Folder_Open_In(folder, skip_file);
        if (!self->post_stream || !self->skip_stream) { 
            CharBuf *mess = MAKE_MESS("Can't open either %o or %o", 
                post_file, skip_file); 
            DECREF(post_file);
            DECREF(skip_file);
            DECREF(self);
            Err_throw_mess(ERR, mess);
        }
    }
    else {
        /*  Empty, so don't bother with these. */
        self->post_stream = NULL;
        self->skip_stream = NULL;
    }
    DECREF(post_file);
    DECREF(skip_file);

    return self;
}

void 
SegPList_destroy(SegPostingList *self)
{
    DECREF(self->post_reader);
    DECREF(self->posting);
    DECREF(self->skip_stepper);
    DECREF(self->field);
    
    if (self->post_stream != NULL) {
        InStream_Close(self->post_stream);
        InStream_Close(self->skip_stream);
        DECREF(self->post_stream);
        DECREF(self->skip_stream);
    }

    SUPER_DESTROY(self, SEGPOSTINGLIST);
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

i32_t
SegPList_get_doc_id(SegPostingList *self) 
{
    return self->posting->doc_id;
}

/* TODO: This is unsafe to call except right after constructor. */
void
SegPList_set_doc_base(SegPostingList *self, i32_t doc_base)
{
    self->doc_base = doc_base;
}

i32_t
SegPList_next(SegPostingList *self) 
{
    InStream *const post_stream = self->post_stream;
    Posting  *const posting     = self->posting;

    /* Bail if we're out of docs. */
    if (self->count >= self->doc_freq) {
        Post_Reset(posting);
        Post_Set_Doc_ID(posting, self->doc_base);
        return 0;
    }
    self->count++;

    Post_Read_Record(posting, post_stream);

    return posting->doc_id;
}

i32_t
SegPList_advance(SegPostingList *self, i32_t target)
{
    Posting *posting          = self->posting;
    const u32_t skip_interval = self->skip_interval;

    if (self->doc_freq >= skip_interval) {
        InStream *post_stream           = self->post_stream;
        InStream *skip_stream           = self->skip_stream;
        SkipStepper *const skip_stepper = self->skip_stepper;
        u32_t new_doc_id                = skip_stepper->doc_id;
        i64_t new_filepos               = InStream_Tell(post_stream);

        /* Assuming the default skip_interval of 16...
         * 
         * Say we're currently on the 5th doc matching this term, and we get a
         * request to skip to the 18th doc matching it.  We won't have skipped
         * yet, but we'll have already gone past 5 of the 16 skip docs --
         * ergo, the modulus in the following formula.
         */
        i32_t num_skipped = 0 - (self->count % skip_interval);

        /* See if there's anything to skip. */
        while (target > skip_stepper->doc_id) {
            new_doc_id    = skip_stepper->doc_id;
            new_filepos   = skip_stepper->filepos;

            if (   skip_stepper->doc_id != self->doc_base 
                && skip_stepper->doc_id >= posting->doc_id
            ) {
                num_skipped += skip_interval;
            }

            if (self->skip_count >= self->num_skips)
                break;

            SkipStepper_Read_Record(skip_stepper, skip_stream);
            self->skip_count++;
        }

        /* If we found something to skip, skip it. */
        if (new_filepos > InStream_Tell(post_stream)) {

            /* Move the postings filepointer up. */
            InStream_Seek(post_stream, new_filepos);

            /* Jump to the new doc id. */
            posting->doc_id = new_doc_id;

            /* Increase count by the number of docs we skipped over. */
            self->count += num_skipped;
        }
    }

    /* Done skipping, so scan. */
    while (1) {
        i32_t doc_id = SegPList_Next(self);
        if (doc_id == 0 || doc_id >= target)
            return doc_id; 
    }
}

void
SegPList_seek(SegPostingList *self, Obj *target)
{
    LexiconReader *lex_reader = PostReader_Get_Lex_Reader(self->post_reader);
    TermInfo      *tinfo      = LexReader_Fetch_Term_Info(lex_reader, 
        self->field, target);
    S_seek_tinfo(self, tinfo);
    DECREF(tinfo);
}

void
SegPList_seek_lex(SegPostingList *self, Lexicon *lexicon)
{
    /* Maybe true, maybe not. */
    SegLexicon *const seg_lexicon = (SegLexicon*)lexicon;

    /* Optimized case. */
    if (   OBJ_IS_A(lexicon, SEGLEXICON)
        && (SegLex_Get_Segment(seg_lexicon) ==
            PostReader_Get_Segment(self->post_reader)) /* i.e. same segment */
    ) {
        S_seek_tinfo(self, SegLex_Get_Term_Info(seg_lexicon));
    }
    /* Punt case.  This is more expensive because of the call to
     * LexReader_Fetch_Term_Info() in Seek(). */
    else {
        Obj *term = Lex_Get_Term(lexicon);
        SegPList_Seek(self, term);
    }
}

static void
S_seek_tinfo(SegPostingList *self, TermInfo *tinfo) 
{
    self->count = 0;

    if (tinfo == NULL) {
        /* Next will return false; other methods invalid now. */
        self->doc_freq = 0;
    }
    else {
        /* Transfer doc_freq, seek main stream. */
        self->doc_freq     = tinfo->doc_freq;
        InStream_Seek(self->post_stream, tinfo->post_filepos);

        /* Prepare posting. */
        Post_Reset(self->posting);
        Post_Set_Doc_ID(self->posting, self->doc_base);

        /* Prepare to skip. */
        self->skip_count    = 0;
        self->num_skips     = tinfo->doc_freq / self->skip_interval;
        SkipStepper_Set_ID_And_Filepos(self->skip_stepper, self->doc_base,
            (u64_t)tinfo->post_filepos);
        InStream_Seek(self->skip_stream, tinfo->skip_filepos);
    }
}

Matcher*
SegPList_make_matcher(SegPostingList *self, Similarity *sim, 
                      Compiler *compiler, bool_t need_score)
{
    return Post_Make_Matcher(self->posting, sim, (PostingList*)self, compiler,
        need_score);
}

RawPosting*
SegPList_read_raw(SegPostingList *self, i32_t last_doc_id, CharBuf *term_text,
                  MemoryPool *mem_pool)
{
    return Post_Read_Raw(self->posting, self->post_stream, 
        last_doc_id, term_text, mem_pool);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */


