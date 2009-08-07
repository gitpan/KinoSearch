#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/LexiconWriter.h"
#include "KinoSearch/Architecture.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Index/TermStepper.h"
#include "KinoSearch/Posting/MatchPosting.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/I32Array.h"

i32_t LexWriter_current_file_format = 3;

LexiconWriter*
LexWriter_new(Schema *schema, Snapshot *snapshot, Segment *segment,
              PolyReader *polyreader)
{
    LexiconWriter *self = (LexiconWriter*)VTable_Make_Obj(LEXICONWRITER);
    return LexWriter_init(self, schema, snapshot, segment, polyreader);
}

LexiconWriter*
LexWriter_init(LexiconWriter *self, Schema *schema, Snapshot *snapshot,
               Segment *segment, PolyReader *polyreader)
{
    Architecture *arch   = Schema_Get_Architecture(schema);

    DataWriter_init((DataWriter*)self, schema, snapshot, segment, polyreader);

    /* Assign. */
    self->index_interval = Arch_Index_Interval(arch);
    self->skip_interval  = Arch_Skip_Interval(arch);

    /* Init. */
    self->ix_out             = NULL;
    self->ixix_out           = NULL;
    self->dat_out            = NULL;
    self->count              = 0;
    self->ix_count           = 0;
    self->dat_file           = CB_new(30);
    self->ix_file            = CB_new(30);
    self->ixix_file          = CB_new(30);
    self->counts             = Hash_new(0);
    self->ix_counts          = Hash_new(0);
    self->temp_mode          = false;
    self->term_stepper       = NULL;
    self->tinfo_stepper      = (TermStepper*)MatchTInfoStepper_new(schema);

    return self;
}

void
LexWriter_destroy(LexiconWriter *self) 
{
    DECREF(self->term_stepper);
    DECREF(self->tinfo_stepper);
    DECREF(self->dat_file);
    DECREF(self->ix_file);
    DECREF(self->ixix_file);
    DECREF(self->dat_out);
    DECREF(self->ix_out);
    DECREF(self->ixix_out);
    DECREF(self->counts);
    DECREF(self->ix_counts);
    SUPER_DESTROY(self, LEXICONWRITER);
}

static void
S_add_last_term_to_ix(LexiconWriter *self)
{
    /* Write file pointer to index record. */
    OutStream_Write_U64(self->ixix_out, OutStream_Tell(self->ix_out));

    /* Write term and file pointer to main record.  Track count of terms added
     * to ix. */
    TermStepper_Write_Key_Frame(self->term_stepper,
        self->ix_out, TermStepper_Get_Value(self->term_stepper));
    TermStepper_Write_Key_Frame(self->tinfo_stepper, 
        self->ix_out, TermStepper_Get_Value(self->tinfo_stepper));
    OutStream_Write_C64(self->ix_out, OutStream_Tell(self->dat_out));
    self->ix_count++;
}

void 
LexWriter_add_term(LexiconWriter* self, CharBuf* term_text, TermInfo* tinfo) 
{
    OutStream *dat_out = self->dat_out;

    if (    (self->count % self->index_interval == 0)
         && !self->temp_mode
    ) {
        /* Write a subset of entries to lexicon.ix. */
        S_add_last_term_to_ix(self);
    }

    TermStepper_Write_Delta(self->term_stepper, dat_out, (Obj*)term_text);
    TermStepper_Write_Delta(self->tinfo_stepper, dat_out, (Obj*)tinfo);

    /* Track number of terms. */
    self->count++;
}

void
LexWriter_start_field(LexiconWriter *self, i32_t field_num)
{
    Segment   *const segment  = LexWriter_Get_Segment(self);
    Folder    *const folder   = LexWriter_Get_Folder(self);
    Snapshot  *const snapshot = LexWriter_Get_Snapshot(self);
    Schema    *const schema   = LexWriter_Get_Schema(self);
    CharBuf   *const seg_name = Seg_Get_Name(segment);
    CharBuf   *const field    = Seg_Field_Name(segment, field_num);
    FieldType *const type    = Schema_Fetch_Type(schema, field);

    /* Open outstreams. */
    CB_setf(self->dat_file,  "%o/lexicon-%i32.dat",  seg_name, field_num);
    CB_setf(self->ix_file,   "%o/lexicon-%i32.ix",   seg_name, field_num);
    CB_setf(self->ixix_file, "%o/lexicon-%i32.ixix", seg_name, field_num);
    Snapshot_Add_Entry(snapshot, self->dat_file);
    Snapshot_Add_Entry(snapshot, self->ix_file);
    Snapshot_Add_Entry(snapshot, self->ixix_file);
    self->dat_out  = Folder_Open_Out(folder, self->dat_file);
    self->ix_out   = Folder_Open_Out(folder, self->ix_file);
    self->ixix_out = Folder_Open_Out(folder, self->ixix_file);
    if (!self->dat_out)  { THROW(ERR, "Can't open %o", self->dat_file); }
    if (!self->ix_out)   { THROW(ERR, "Can't open %o", self->ix_file); }
    if (!self->ixix_out) { THROW(ERR, "Can't open %o", self->ixix_file); }

    /* Initialize count and ix_count, term stepper and term info stepper. */
    self->count    = 0;
    self->ix_count = 0;
    self->term_stepper = FType_Make_Term_Stepper(type);
    TermStepper_Reset(self->tinfo_stepper);
}

void
LexWriter_finish_field(LexiconWriter *self, i32_t field_num)
{
    CharBuf *field = Seg_Field_Name(self->segment, field_num);
    
    /* Store count of terms for this field as metadata. */
    Hash_Store(self->counts, (Obj*)field, 
        (Obj*)CB_newf("%i32", self->count));
    Hash_Store(self->ix_counts, (Obj*)field, 
        (Obj*)CB_newf("%i32", self->ix_count));

    /* Close streams. */
    OutStream_Close(self->dat_out);
    OutStream_Close(self->ix_out);
    OutStream_Close(self->ixix_out);
    DECREF(self->dat_out);
    DECREF(self->ix_out);
    DECREF(self->ixix_out);
    self->dat_out  = NULL;
    self->ix_out   = NULL;
    self->ixix_out = NULL;

    /* Close term stepper. */
    DECREF(self->term_stepper);
    self->term_stepper = NULL;
}

void
LexWriter_enter_temp_mode(LexiconWriter *self, const CharBuf *field, 
                          OutStream *temp_outstream)
{
    Schema    *schema = LexWriter_Get_Schema(self);
    FieldType *type   = Schema_Fetch_Type(schema, field);

    /* Assign outstream. */
    if (self->dat_out != NULL)
        THROW(ERR, "Can't enter temp mode (filename: %o) ", self->dat_file);
    self->dat_out = (OutStream*)INCREF(temp_outstream);

    /* Initialize count and ix_count, term stepper and term info stepper. */
    self->count    = 0;
    self->ix_count = 0;
    self->term_stepper = FType_Make_Term_Stepper(type);
    TermStepper_Reset(self->tinfo_stepper);

    /* Remember that we're in temp mode. */
    self->temp_mode = true;
}

void
LexWriter_leave_temp_mode(LexiconWriter *self)
{
    DECREF(self->term_stepper);
    self->term_stepper = NULL;
    DECREF(self->dat_out);
    self->dat_out = NULL;
    self->temp_mode = false;
}

void
LexWriter_finish(LexiconWriter *self)
{
    /* Ensure that streams were closed (by calling Finish_Field or
     * Leave_Temp_Mode). */
    if (self->dat_out != NULL) {
        THROW(ERR, "File '%o' never closed", self->dat_file);
    }
    else if (self->ix_out != NULL) {
        THROW(ERR, "File '%o' never closed", self->ix_file);
    }
    else if (self->ix_out != NULL) {
        THROW(ERR, "File '%o' never closed", self->ix_file);
    }

    /* Store metadata. */
    Seg_Store_Metadata_Str(self->segment, "lexicon", 7,
        (Obj*)LexWriter_Metadata(self));
}

Hash*
LexWriter_metadata(LexiconWriter *self)
{
    Hash *const metadata  = DataWriter_metadata((DataWriter*)self);
    Hash *const counts    = (Hash*)INCREF(self->counts);
    Hash *const ix_counts = (Hash*)INCREF(self->ix_counts);

    /* Placeholders. */
    if (Hash_Get_Size(counts) == 0) {
        Hash_Store_Str(counts, "none", 4, (Obj*)CB_newf("%i32", (i32_t)0) );
        Hash_Store_Str(ix_counts, "none", 4, 
            (Obj*)CB_newf("%i32", (i32_t)0) );
    }

    Hash_Store_Str(metadata, "counts", 6, (Obj*)counts);
    Hash_Store_Str(metadata, "index_counts", 12, (Obj*)ix_counts);

    return metadata;
}

static bool_t 
S_my_file(VArray *array, u32_t tick, void *data)
{
    CharBuf *file_start = (CharBuf*)data;
    CharBuf *candidate = (CharBuf*)VA_Fetch(array, tick);
    return CB_Starts_With(candidate, file_start);
}

void
LexWriter_add_segment(LexiconWriter *self, SegReader *reader, 
                      I32Array *doc_map)
{
    /* No-op, since the data gets added via PostingsWriter. */
    UNUSED_VAR(self);
    UNUSED_VAR(reader);
    UNUSED_VAR(doc_map);
}

void
LexWriter_delete_segment(LexiconWriter *self, SegReader *reader)
{
    Snapshot *snapshot = LexWriter_Get_Snapshot(self);
    CharBuf  *merged_seg_name = Seg_Get_Name(SegReader_Get_Segment(reader));
    CharBuf  *pattern  = CB_newf("%o/lexicon", merged_seg_name);
    VArray   *files = Snapshot_List(snapshot);
    VArray   *my_old_files = VA_Grep(files, S_my_file, pattern);
    u32_t i, max;

    for (i = 0, max = VA_Get_Size(my_old_files); i < max; i++) {
        CharBuf *entry = (CharBuf*)VA_Fetch(my_old_files, i);
        Snapshot_Delete_Entry(snapshot, entry);
    }
    DECREF(my_old_files);
    DECREF(files);
    DECREF(pattern);
}

i32_t
LexWriter_format(LexiconWriter *self)
{
    UNUSED_VAR(self);
    return LexWriter_current_file_format;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
