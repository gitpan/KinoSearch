#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SegLexicon.h"
#include "KinoSearch/Architecture.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/PostingList.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Index/LexIndex.h"
#include "KinoSearch/Index/LexStepper.h"
#include "KinoSearch/Index/LexiconWriter.h"
#include "KinoSearch/Index/SegPostingList.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Util/I32Array.h"

/* Iterate until the state is greater than or equal to the target.
 */
static void
S_scan_to(SegLexicon *self, Obj *target);

SegLexicon*
SegLex_new(Schema *schema, Folder *folder, Segment *segment, 
           const CharBuf *field)
{
    SegLexicon *self = (SegLexicon*)VTable_Make_Obj(&SEGLEXICON);
    return SegLex_init(self, schema, folder, segment, field);
}

SegLexicon*
SegLex_init(SegLexicon *self, Schema *schema, Folder *folder, 
            Segment *segment, const CharBuf *field)
{
    Hash *metadata = (Hash*)ASSERT_IS_A(
        Seg_Fetch_Metadata_Str(segment, "lexicon", 7), HASH);
    Architecture *arch      = Schema_Get_Architecture(schema);
    Hash         *counts    = (Hash*)Hash_Fetch_Str(metadata, "counts", 6);
    Obj          *format    = Hash_Fetch_Str(metadata, "format", 6);
    CharBuf      *seg_name  = Seg_Get_Name(segment);
    i32_t         field_num = Seg_Field_Num(segment, field);
    CharBuf *filename = CB_newf("%o/lexicon-%i32.dat", seg_name, field_num);

    /* Check format. */
    if (!format) { THROW("Missing 'format'"); }
    else {
        if (Obj_To_I64(format) > LexWriter_current_file_format) {
            THROW("Unsupported lexicon format: %i64",
                Obj_To_I64(format));
        }
    }

    /* Extract count from metadata. */
    if (!counts) { THROW("Failed to extract 'counts'"); }
    else {
        Obj *count = ASSERT_IS_A(Hash_Fetch(counts, field), OBJ);
        self->size = (i32_t)Obj_To_I64(count);
    }

    /* Assign. */
    self->field          = CB_Clone(field);
    self->segment        = (Segment*)INCREF(segment);

    /* Derive. */
    self->lex_index      = LexIndex_new(schema, folder, segment, field);
    self->field_num      = field_num;
    self->index_interval = Arch_Index_Interval(arch);
    self->skip_interval  = Arch_Skip_Interval(arch);
    self->instream       = Folder_Open_In(folder, filename);
    if (!self->instream) {
        CharBuf *mess = MAKE_MESS("Can't open %o", filename);
        DECREF(filename);
        DECREF(self);
        Err_throw_mess(mess);
    }
    DECREF(filename);

    /* Define the term_num as "not yet started". */
    self->term_num = -1;

    /* Get a LexStepper. */
    self->lex_stepper = LexStepper_new(field, self->skip_interval);

    return self;
}

void
SegLex_destroy(SegLexicon *self) 
{
    DECREF(self->segment);
    DECREF(self->lex_stepper);
    DECREF(self->field);
    DECREF(self->lex_index);
    DECREF(self->instream);
    FREE_OBJ(self);
}

void
SegLex_seek(SegLexicon *self, Obj *target)
{
    LexIndex *const lex_index = self->lex_index;

    /* Reset upon null term. */
    if (target == NULL) {
        SegLex_Reset(self);
        return;
    }

    /* Use the LexIndex to get in the ballpark. */
    LexIndex_Seek(lex_index, target);
    LexStepper_Set_TInfo(self->lex_stepper, 
        LexIndex_Get_Term_Info(lex_index));
    LexStepper_Set_Value(self->lex_stepper, LexIndex_Get_Term(lex_index));
    InStream_Seek(self->instream, self->lex_stepper->tinfo->lex_filepos);
    self->term_num = LexIndex_Get_Term_Num(lex_index);

    /* Scan to the precise location. */
    S_scan_to(self, target);
}

void
SegLex_reset(SegLexicon* self) 
{
    self->term_num = -1;
    InStream_Seek(self->instream, 0);
    LexStepper_Reset(self->lex_stepper);
}

i32_t
SegLex_get_field_num(SegLexicon *self)
{
    return self->field_num;
}

Obj*
SegLex_get_term(SegLexicon *self)
{
    return self->lex_stepper->value;
}

TermInfo*
SegLex_get_term_info(SegLexicon *self)
{
    return self->lex_stepper->tinfo;
}

Segment*
SegLex_get_segment(SegLexicon *self) { return self->segment; }

bool_t 
SegLex_next(SegLexicon *self) 
{
    /* If we've run out of terms, null out and return. */
    if (++self->term_num >= self->size) {
        self->term_num = self->size; /* don't keep growing */
        LexStepper_Reset(self->lex_stepper);
        return false;
    }

    /* Read next term/terminfo. */
    LexStepper_Read_Record(self->lex_stepper, self->instream);

    return true;
}

static void
S_scan_to(SegLexicon *self, Obj *target)
{
    /* (mildly evil encapsulation violation, since value can be null) */
    Obj *current = self->lex_stepper->value;
    if ( !Obj_Is_A(target, Obj_Get_VTable(current)) ) { 
        THROW("Target is a %o, and not comparable to a %o",
            Obj_Get_Class_Name(target), Obj_Get_Class_Name(current));
    }

    /* Keep looping until the term text is ge target. */
    do {
        const i32_t comparison = Obj_Compare_To(current, target);
        if (comparison >= 0 &&  self->term_num != -1) { break; }
    } while (SegLex_Next(self));
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

