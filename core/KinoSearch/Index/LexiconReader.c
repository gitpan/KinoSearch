#define C_KINO_LEXICONREADER
#define C_KINO_POLYLEXICONREADER
#define C_KINO_DEFAULTLEXICONREADER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/LexiconReader.h"
#include "KinoSearch/Plan/FieldType.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Index/PolyLexicon.h"
#include "KinoSearch/Index/SegLexicon.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Index/TermInfo.h"
#include "KinoSearch/Store/Folder.h"

LexiconReader*
LexReader_init(LexiconReader *self, Schema *schema, Folder *folder,
               Snapshot *snapshot, VArray *segments, int32_t seg_tick)
{
    DataReader_init((DataReader*)self, schema, folder, snapshot, segments,
        seg_tick);
    ABSTRACT_CLASS_CHECK(self, LEXICONREADER);
    return self;
}

LexiconReader*
LexReader_aggregator(LexiconReader *self, VArray *readers, I32Array *offsets)
{
    UNUSED_VAR(self);
    return (LexiconReader*)PolyLexReader_new(readers, offsets);
}

PolyLexiconReader*
PolyLexReader_new(VArray *readers, I32Array *offsets)
{
    PolyLexiconReader *self 
        = (PolyLexiconReader*)VTable_Make_Obj(POLYLEXICONREADER);
    return PolyLexReader_init(self, readers, offsets);
}

PolyLexiconReader*
PolyLexReader_init(PolyLexiconReader *self, VArray *readers, 
                   I32Array *offsets)
{
    uint32_t i, max;
    Schema *schema = NULL;
    for (i = 0, max = VA_Get_Size(readers); i < max; i++) {
        LexiconReader *reader = (LexiconReader*)CERTIFY(
            VA_Fetch(readers, i), LEXICONREADER);
        if (!schema) { schema = LexReader_Get_Schema(reader); }
    }
    LexReader_init((LexiconReader*)self, schema, NULL, NULL, NULL, -1);
    self->readers = (VArray*)INCREF(readers);
    self->offsets = (I32Array*)INCREF(offsets);
    return self;
}

void
PolyLexReader_close(PolyLexiconReader *self)
{
    if (self->readers) {
        uint32_t i, max;
        for (i = 0, max = VA_Get_Size(self->readers); i < max; i++) {
            LexiconReader *reader 
                = (LexiconReader*)VA_Fetch(self->readers, i);
            if (reader) { LexReader_Close(reader); }
        }
        VA_Clear(self->readers);
    }
}

void
PolyLexReader_destroy(PolyLexiconReader *self)
{
    DECREF(self->readers);
    DECREF(self->offsets);
    SUPER_DESTROY(self, POLYLEXICONREADER);
}

Lexicon*
PolyLexReader_lexicon(PolyLexiconReader *self, const CharBuf *field,
                      Obj *term)
{
    PolyLexicon *lexicon = NULL;

    if (field != NULL) {
        Schema *schema = PolyLexReader_Get_Schema(self);
        FieldType *type = Schema_Fetch_Type(schema, field);
        if (type != NULL) {
            lexicon = PolyLex_new(field, self->readers);
            if (!PolyLex_Get_Num_Seg_Lexicons(lexicon)) {
                DECREF(lexicon);
                return NULL;
            }
            if (term) { PolyLex_Seek(lexicon, term); }
        }
    }

    return (Lexicon*)lexicon;
}

uint32_t
PolyLexReader_doc_freq(PolyLexiconReader *self, const CharBuf *field,
                       Obj *term)
{
    uint32_t doc_freq = 0;
    uint32_t i, max;
    for (i = 0, max = VA_Get_Size(self->readers); i < max; i++) {
        LexiconReader *reader = (LexiconReader*)VA_Fetch(self->readers, i);
        if (reader) {
            doc_freq += LexReader_Doc_Freq(reader, field, term);
        }
    }
    return doc_freq;
}

DefaultLexiconReader*
DefLexReader_new(Schema *schema, Folder *folder, Snapshot *snapshot,
                 VArray *segments, int32_t seg_tick)
{
    DefaultLexiconReader *self 
        = (DefaultLexiconReader*)VTable_Make_Obj(DEFAULTLEXICONREADER);
    return DefLexReader_init(self, schema, folder, snapshot, segments, 
        seg_tick);
}

// Indicate whether it is safe to build a SegLexicon using the given
// parameters. Will return false if the field is not indexed or if no terms
// are present for this field in this segment.
static bool_t
S_has_data(Schema *schema, Folder *folder, Segment *segment, CharBuf *field)
{
    FieldType *type = Schema_Fetch_Type(schema, field);

    if ( !type || !FType_Indexed(type)) {
        // If the field isn't indexed, bail out. 
        return false;
    }
    else {
        // Bail out if there are no terms for this field in this segment. 
        int32_t field_num   = Seg_Field_Num(segment, field);
        CharBuf *seg_name = Seg_Get_Name(segment);
        CharBuf *file = CB_newf("%o/lexicon-%i32.dat", seg_name, field_num);
        bool_t retval = Folder_Exists(folder, file);
        DECREF(file);
        return retval;
    }
}

DefaultLexiconReader*
DefLexReader_init(DefaultLexiconReader *self, Schema *schema, Folder *folder,
               Snapshot *snapshot, VArray *segments, int32_t seg_tick)
{
    Segment *segment;
    uint32_t i, max;

    // Init. 
    LexReader_init((LexiconReader*)self, schema, folder, snapshot, segments,
        seg_tick);
    segment = DefLexReader_Get_Segment(self);

    // Build an array of SegLexicon objects. 
    self->lexicons = VA_new(Schema_Num_Fields(schema));
    for (i = 1, max = Schema_Num_Fields(schema) + 1; i < max; i++) {
        CharBuf *field = Seg_Field_Name(segment, i);
        if (field && S_has_data(schema, folder, segment, field)) {
            SegLexicon *lexicon = SegLex_new(schema, folder, segment, field);
            VA_Store(self->lexicons, i, (Obj*)lexicon);
        }
    }

    return self;
}

void
DefLexReader_close(DefaultLexiconReader *self)
{
    DECREF(self->lexicons);
    self->lexicons = NULL;
}

void
DefLexReader_destroy(DefaultLexiconReader *self)
{
    DECREF(self->lexicons);
    SUPER_DESTROY(self, DEFAULTLEXICONREADER);
}

Lexicon*
DefLexReader_lexicon(DefaultLexiconReader *self, const CharBuf *field, 
                     Obj *term)
{
    int32_t     field_num = Seg_Field_Num(self->segment, field);
    SegLexicon *orig      = (SegLexicon*)VA_Fetch(self->lexicons, field_num);
    SegLexicon *lexicon   = NULL;

    if (orig) { // i.e. has data 
        lexicon 
            = SegLex_new(self->schema, self->folder, self->segment, field);
        SegLex_Seek(lexicon, term);
    }

    return (Lexicon*)lexicon;
}

static TermInfo* 
S_find_tinfo(DefaultLexiconReader *self, const CharBuf *field, Obj *target)
{    
    if (field != NULL && target != NULL) {
        int32_t field_num = Seg_Field_Num(self->segment, field);
        SegLexicon *lexicon 
            = (SegLexicon*)VA_Fetch(self->lexicons, field_num);

        if (lexicon) {
            // Iterate until the result is ge the term.  
            SegLex_Seek(lexicon, target);

            //if found matches target, return info; otherwise NULL 
            {
                Obj *found = SegLex_Get_Term(lexicon);
                if (found && Obj_Equals(target, found)) {
                    return SegLex_Get_Term_Info(lexicon);
                }
            }
        }
    }
    return NULL;
}

TermInfo*
DefLexReader_fetch_term_info(DefaultLexiconReader *self, 
                             const CharBuf *field, Obj *target) 
{    
    TermInfo *tinfo = S_find_tinfo(self, field, target);
    return tinfo ? TInfo_Clone(tinfo) : NULL;
}

uint32_t
DefLexReader_doc_freq(DefaultLexiconReader *self, const CharBuf *field,
                      Obj *term)
{
    TermInfo *tinfo = S_find_tinfo(self, field, term);
    return tinfo ? TInfo_Get_Doc_Freq(tinfo) : 0;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

