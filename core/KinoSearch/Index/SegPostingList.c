#define C_KINO_SEGPOSTINGLIST
#define C_KINO_POSTING
#define C_KINO_SKIPSTEPPER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SegPostingList.h"
#include "KinoSearch/Index/Posting.h"
#include "KinoSearch/Index/Posting/RawPosting.h"
#include "KinoSearch/Index/PostingListReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SkipStepper.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Index/SegLexicon.h"
#include "KinoSearch/Index/LexiconReader.h"
#include "KinoSearch/Index/Similarity.h"
#include "KinoSearch/Plan/Architecture.h"
#include "KinoSearch/Plan/FieldType.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Search/Compiler.h"
#include "KinoSearch/Search/Matcher.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/MemoryPool.h"

// Low level seek call. 
static void
S_seek_tinfo(SegPostingList *self, TermInfo *tinfo);

SegPostingList*
SegPList_new(PostingListReader *plist_reader, const CharBuf *field)
{
    SegPostingList *self = (SegPostingList*)VTable_Make_Obj(SEGPOSTINGLIST);
    return SegPList_init(self, plist_reader, field);
}

SegPostingList*
SegPList_init(SegPostingList *self, PostingListReader *plist_reader, 
              const CharBuf *field)
{
    Schema       *const schema   = PListReader_Get_Schema(plist_reader);
    Folder       *const folder   = PListReader_Get_Folder(plist_reader);
    Segment      *const segment  = PListReader_Get_Segment(plist_reader);
    Architecture *const arch     = Schema_Get_Architecture(schema);
    CharBuf      *const seg_name = Seg_Get_Name(segment);
    int32_t       field_num      = Seg_Field_Num(segment, field);
    CharBuf      *post_file      = CB_newf("%o/postings-%i32.dat", 
                                           seg_name, field_num);
    CharBuf      *skip_file      = CB_newf("%o/postings.skip", seg_name);

    // Init. 
    self->doc_freq        = 0;
    self->count           = 0;

    // Init skipping vars. 
    self->skip_stepper    = SkipStepper_new();
    self->skip_count      = 0;
    self->num_skips       = 0;

    // Assign. 
    self->plist_reader    = (PostingListReader*)INCREF(plist_reader);
    self->field           = CB_Clone(field);
    self->skip_interval   = Arch_Skip_Interval(arch);
    
    // Derive. 
    Similarity *sim = Schema_Fetch_Sim(schema, field);
    self->posting   = Sim_Make_Posting(sim);
    self->field_num = field_num;

    // Open both a main stream and a skip stream if the field exists. 
    if (Folder_Exists(folder, post_file)) {
        self->post_stream = Folder_Open_In(folder, post_file);
        if (!self->post_stream) {
            Err *error = (Err*)INCREF(Err_get_error());
            DECREF(post_file);
            DECREF(skip_file);
            DECREF(self);
            RETHROW(error);
        }
        self->skip_stream = Folder_Open_In(folder, skip_file);
        if (!self->skip_stream) { 
            Err *error = (Err*)INCREF(Err_get_error());
            DECREF(post_file);
            DECREF(skip_file);
            DECREF(self);
            RETHROW(error);
        }
    }
    else {
        //  Empty, so don't bother with these. 
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
    DECREF(self->plist_reader);
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

uint32_t
SegPList_get_doc_freq(SegPostingList *self) 
{
    return self->doc_freq;
}

int32_t
SegPList_get_doc_id(SegPostingList *self) 
{
    return self->posting->doc_id;
}

uint32_t
SegPList_get_count(SegPostingList *self) { return self->count; }
InStream*
SegPList_get_post_stream(SegPostingList *self) { return self->post_stream; }

int32_t
SegPList_next(SegPostingList *self) 
{
    InStream *const post_stream = self->post_stream;
    Posting  *const posting     = self->posting;

    // Bail if we're out of docs. 
    if (self->count >= self->doc_freq) {
        Post_Reset(posting);
        return 0;
    }
    self->count++;

    Post_Read_Record(posting, post_stream);

    return posting->doc_id;
}

int32_t
SegPList_advance(SegPostingList *self, int32_t target)
{
    Posting *posting          = self->posting;
    const uint32_t skip_interval = self->skip_interval;

    if (self->doc_freq >= skip_interval) {
        InStream *post_stream           = self->post_stream;
        InStream *skip_stream           = self->skip_stream;
        SkipStepper *const skip_stepper = self->skip_stepper;
        uint32_t new_doc_id             = skip_stepper->doc_id;
        int64_t new_filepos             = InStream_Tell(post_stream);

        /* Assuming the default skip_interval of 16...
         * 
         * Say we're currently on the 5th doc matching this term, and we get a
         * request to skip to the 18th doc matching it.  We won't have skipped
         * yet, but we'll have already gone past 5 of the 16 skip docs --
         * ergo, the modulus in the following formula.
         */
        int32_t num_skipped = 0 - (self->count % skip_interval);
        if (num_skipped == 0 && self->count != 0) { 
            num_skipped = 0 - skip_interval; 
        }

        // See if there's anything to skip. 
        while (target > skip_stepper->doc_id) {
            new_doc_id    = skip_stepper->doc_id;
            new_filepos   = skip_stepper->filepos;

            if (   skip_stepper->doc_id != 0 
                && skip_stepper->doc_id >= posting->doc_id
            ) {
                num_skipped += skip_interval;
            }

            if (self->skip_count >= self->num_skips)
                break;

            SkipStepper_Read_Record(skip_stepper, skip_stream);
            self->skip_count++;
        }

        // If we found something to skip, skip it. 
        if (new_filepos > InStream_Tell(post_stream)) {

            // Move the postings filepointer up. 
            InStream_Seek(post_stream, new_filepos);

            // Jump to the new doc id. 
            posting->doc_id = new_doc_id;

            // Increase count by the number of docs we skipped over. 
            self->count += num_skipped;
        }
    }

    // Done skipping, so scan. 
    while (1) {
        int32_t doc_id = SegPList_Next(self);
        if (doc_id == 0 || doc_id >= target)
            return doc_id; 
    }
}

void
SegPList_seek(SegPostingList *self, Obj *target)
{
    LexiconReader *lex_reader = PListReader_Get_Lex_Reader(self->plist_reader);
    TermInfo      *tinfo      = LexReader_Fetch_Term_Info(lex_reader, 
        self->field, target);
    S_seek_tinfo(self, tinfo);
    DECREF(tinfo);
}

void
SegPList_seek_lex(SegPostingList *self, Lexicon *lexicon)
{
    // Maybe true, maybe not. 
    SegLexicon *const seg_lexicon = (SegLexicon*)lexicon;

    // Optimized case. 
    if (   Obj_Is_A((Obj*)lexicon, SEGLEXICON)
        && (SegLex_Get_Segment(seg_lexicon) ==
            PListReader_Get_Segment(self->plist_reader)) // i.e. same segment 
    ) {
        S_seek_tinfo(self, SegLex_Get_Term_Info(seg_lexicon));
    }
    // Punt case.  This is more expensive because of the call to
    // LexReader_Fetch_Term_Info() in Seek().
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
        // Next will return false; other methods invalid now. 
        self->doc_freq = 0;
    }
    else {
        // Transfer doc_freq, seek main stream. 
        int64_t post_filepos = TInfo_Get_Post_FilePos(tinfo);
        self->doc_freq       = TInfo_Get_Doc_Freq(tinfo);
        InStream_Seek(self->post_stream, post_filepos);

        // Prepare posting. 
        Post_Reset(self->posting);

        // Prepare to skip. 
        self->skip_count    = 0;
        self->num_skips     = self->doc_freq / self->skip_interval;
        SkipStepper_Set_ID_And_Filepos(self->skip_stepper, 0, post_filepos);
        InStream_Seek(self->skip_stream, TInfo_Get_Skip_FilePos(tinfo));
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
SegPList_read_raw(SegPostingList *self, int32_t last_doc_id, CharBuf *term_text,
                  MemoryPool *mem_pool)
{
    return Post_Read_Raw(self->posting, self->post_stream, 
        last_doc_id, term_text, mem_pool);
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */


