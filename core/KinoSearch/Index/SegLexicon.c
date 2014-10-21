#define C_KINO_SEGLEXICON
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SegLexicon.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/PostingList.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Index/LexIndex.h"
#include "KinoSearch/Index/LexiconWriter.h"
#include "KinoSearch/Index/Posting/MatchPosting.h"
#include "KinoSearch/Index/SegPostingList.h"
#include "KinoSearch/Index/TermStepper.h"
#include "KinoSearch/Plan/Architecture.h"
#include "KinoSearch/Plan/FieldType.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/InStream.h"

// Iterate until the state is greater than or equal to the target.
static void
S_scan_to(SegLexicon *self, Obj *target);

SegLexicon*
SegLex_new(Schema *schema, Folder *folder, Segment *segment, 
           const CharBuf *field)
{
    SegLexicon *self = (SegLexicon*)VTable_Make_Obj(SEGLEXICON);
    return SegLex_init(self, schema, folder, segment, field);
}

SegLexicon*
SegLex_init(SegLexicon *self, Schema *schema, Folder *folder, 
            Segment *segment, const CharBuf *field)
{
    Hash *metadata = (Hash*)CERTIFY(
        Seg_Fetch_Metadata_Str(segment, "lexicon", 7), HASH);
    Architecture *arch      = Schema_Get_Architecture(schema);
    Hash         *counts    = (Hash*)Hash_Fetch_Str(metadata, "counts", 6);
    Obj          *format    = Hash_Fetch_Str(metadata, "format", 6);
    CharBuf      *seg_name  = Seg_Get_Name(segment);
    int32_t       field_num = Seg_Field_Num(segment, field);
    FieldType    *type      = Schema_Fetch_Type(schema, field);
    CharBuf *filename = CB_newf("%o/lexicon-%i32.dat", seg_name, field_num);

    Lex_init((Lexicon*)self, field);
    
    // Check format. 
    if (!format) { THROW(ERR, "Missing 'format'"); }
    else {
        if (Obj_To_I64(format) > LexWriter_current_file_format) {
            THROW(ERR, "Unsupported lexicon format: %i64",
                Obj_To_I64(format));
        }
    }

    // Extract count from metadata. 
    if (!counts) { THROW(ERR, "Failed to extract 'counts'"); }
    else {
        Obj *count = CERTIFY(Hash_Fetch(counts, (Obj*)field), OBJ);
        self->size = (int32_t)Obj_To_I64(count);
    }

    // Assign. 
    self->segment        = (Segment*)INCREF(segment);

    // Derive. 
    self->lex_index      = LexIndex_new(schema, folder, segment, field);
    self->field_num      = field_num;
    self->index_interval = Arch_Index_Interval(arch);
    self->skip_interval  = Arch_Skip_Interval(arch);
    self->instream       = Folder_Open_In(folder, filename);
    if (!self->instream) {
        Err *error = (Err*)INCREF(Err_get_error());
        DECREF(filename);
        DECREF(self);
        RETHROW(error);
    }
    DECREF(filename);

    // Define the term_num as "not yet started". 
    self->term_num = -1;

    // Get steppers. 
    self->term_stepper  = FType_Make_Term_Stepper(type);
    self->tinfo_stepper = (TermStepper*)MatchTInfoStepper_new(schema);

    return self;
}

void
SegLex_destroy(SegLexicon *self) 
{
    DECREF(self->segment);
    DECREF(self->term_stepper);
    DECREF(self->tinfo_stepper);
    DECREF(self->lex_index);
    DECREF(self->instream);
    SUPER_DESTROY(self, SEGLEXICON);
}

void
SegLex_seek(SegLexicon *self, Obj *target)
{
    LexIndex *const lex_index = self->lex_index;

    // Reset upon null term. 
    if (target == NULL) {
        SegLex_Reset(self);
        return;
    }

    // Use the LexIndex to get in the ballpark. 
    LexIndex_Seek(lex_index, target);
    {
        TermInfo *target_tinfo = LexIndex_Get_Term_Info(lex_index);
        TermInfo *my_tinfo
            = (TermInfo*)TermStepper_Get_Value(self->tinfo_stepper);
        Obj *lex_index_term = Obj_Clone(LexIndex_Get_Term(lex_index));
        TInfo_Mimic(my_tinfo, (Obj*)target_tinfo);
        TermStepper_Set_Value(self->term_stepper, lex_index_term);
        DECREF(lex_index_term);
        InStream_Seek(self->instream, TInfo_Get_Lex_FilePos(target_tinfo));
    }
    self->term_num = LexIndex_Get_Term_Num(lex_index);

    // Scan to the precise location. 
    S_scan_to(self, target);
}

void
SegLex_reset(SegLexicon* self) 
{
    self->term_num = -1;
    InStream_Seek(self->instream, 0);
    TermStepper_Reset(self->term_stepper);
    TermStepper_Reset(self->tinfo_stepper);
}

int32_t
SegLex_get_field_num(SegLexicon *self)
{
    return self->field_num;
}

Obj*
SegLex_get_term(SegLexicon *self)
{
    return TermStepper_Get_Value(self->term_stepper);
}

int32_t
SegLex_doc_freq(SegLexicon *self)
{
    TermInfo *tinfo = (TermInfo*)TermStepper_Get_Value(self->tinfo_stepper);
    return tinfo ? TInfo_Get_Doc_Freq(tinfo) : 0;
}

TermInfo*
SegLex_get_term_info(SegLexicon *self)
{
    return (TermInfo*)TermStepper_Get_Value(self->tinfo_stepper);
}

Segment*
SegLex_get_segment(SegLexicon *self) { return self->segment; }

bool_t 
SegLex_next(SegLexicon *self) 
{
    // If we've run out of terms, null out and return. 
    if (++self->term_num >= self->size) {
        self->term_num = self->size; // don't keep growing 
        TermStepper_Reset(self->term_stepper);
        TermStepper_Reset(self->tinfo_stepper);
        return false;
    }

    // Read next term/terminfo. 
    TermStepper_Read_Delta(self->term_stepper, self->instream);
    TermStepper_Read_Delta(self->tinfo_stepper, self->instream);

    return true;
}

static void
S_scan_to(SegLexicon *self, Obj *target)
{
    // (mildly evil encapsulation violation, since value can be null) 
    Obj *current = TermStepper_Get_Value(self->term_stepper);
    if ( !Obj_Is_A(target, Obj_Get_VTable(current)) ) { 
        THROW(ERR, "Target is a %o, and not comparable to a %o",
            Obj_Get_Class_Name(target), Obj_Get_Class_Name(current));
    }

    // Keep looping until the term text is ge target. 
    do {
        const int32_t comparison = Obj_Compare_To(current, target);
        if (comparison >= 0 &&  self->term_num != -1) { break; }
    } while (SegLex_Next(self));
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

