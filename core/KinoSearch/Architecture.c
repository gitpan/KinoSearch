#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Architecture.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/DeletionsReader.h"
#include "KinoSearch/Index/DeletionsWriter.h"
#include "KinoSearch/Index/DocReader.h"
#include "KinoSearch/Index/DocWriter.h"
#include "KinoSearch/Index/HighlightReader.h"
#include "KinoSearch/Index/HighlightWriter.h"
#include "KinoSearch/Index/LexiconReader.h"
#include "KinoSearch/Index/LexiconWriter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/PostingsReader.h"
#include "KinoSearch/Index/PostingsWriter.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/SegWriter.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Index/SortReader.h"
#include "KinoSearch/Index/SortWriter.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Store/Folder.h"

Architecture*
Arch_new()
{
    Architecture *self = (Architecture*)VTable_Make_Obj(&ARCHITECTURE);
    return Arch_init(self);
}

Architecture*
Arch_init(Architecture *self)
{
    return self;
}

bool_t
Arch_equals(Architecture *self, Obj *other)
{
    Architecture *evil_twin = (Architecture*)other;
    if (evil_twin == self) return true;
    if (!OBJ_IS_A(evil_twin, ARCHITECTURE)) return false;
    return true;
}

void
Arch_init_seg_writer(Architecture *self, SegWriter *writer)
{
    Arch_Register_Lexicon_Writer(self, writer);
    Arch_Register_Postings_Writer(self, writer);
    Arch_Register_Sort_Writer(self, writer);
    Arch_Register_Doc_Writer(self, writer);
    Arch_Register_Highlight_Writer(self, writer);
    Arch_Register_Deletions_Writer(self, writer);
}

void
Arch_register_lexicon_writer(Architecture *self, SegWriter *writer)
{
    Snapshot      *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment       *segment    = SegWriter_Get_Segment(writer);
    PolyReader    *polyreader = SegWriter_Get_PolyReader(writer);
    LexiconWriter *lex_writer 
        = LexWriter_new(snapshot, segment, polyreader);
    UNUSED_VAR(self);
    SegWriter_Register(writer, LEXICONWRITER.name, 
        (DataWriter*)lex_writer);
}

void
Arch_register_postings_writer(Architecture *self, SegWriter *writer)
{
    Snapshot      *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment       *segment    = SegWriter_Get_Segment(writer);
    PolyReader    *polyreader = SegWriter_Get_PolyReader(writer);
    LexiconWriter *lex_writer 
        = (LexiconWriter*)SegWriter_Fetch(writer, LEXICONWRITER.name);
    UNUSED_VAR(self);
    if (!lex_writer) {
        THROW("Can't fetch a LexiconWriter");
    }
    else {
        PostingsWriter *post_writer 
            = PostWriter_new(snapshot, segment, polyreader, lex_writer);
        SegWriter_Register(writer, POSTINGSWRITER.name, 
            (DataWriter*)post_writer);
        SegWriter_Add_Writer(writer, (DataWriter*)INCREF(post_writer));
    }
}

void
Arch_register_doc_writer(Architecture *self, SegWriter *writer)
{
    Snapshot   *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment    *segment    = SegWriter_Get_Segment(writer);
    PolyReader *polyreader = SegWriter_Get_PolyReader(writer);
    DocWriter *doc_writer 
        = DocWriter_new(snapshot, segment, polyreader);
    UNUSED_VAR(self);
    SegWriter_Register(writer, DOCWRITER.name, (DataWriter*)doc_writer);
    SegWriter_Add_Writer(writer, (DataWriter*)INCREF(doc_writer));
}

void
Arch_register_sort_writer(Architecture *self, SegWriter *writer)
{
    Snapshot   *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment    *segment    = SegWriter_Get_Segment(writer);
    PolyReader *polyreader = SegWriter_Get_PolyReader(writer);
    SortWriter *sort_writer 
        = SortWriter_new(snapshot, segment, polyreader);
    UNUSED_VAR(self);
    SegWriter_Register(writer, SORTWRITER.name, 
        (DataWriter*)sort_writer);
    SegWriter_Add_Writer(writer, (DataWriter*)INCREF(sort_writer));
}

void
Arch_register_highlight_writer(Architecture *self, SegWriter *writer)
{
    Snapshot   *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment    *segment    = SegWriter_Get_Segment(writer);
    PolyReader *polyreader = SegWriter_Get_PolyReader(writer);
    HighlightWriter *hl_writer = HLWriter_new(snapshot, segment, polyreader);
    UNUSED_VAR(self);
    SegWriter_Register(writer, HIGHLIGHTWRITER.name, (DataWriter*)hl_writer);
    SegWriter_Add_Writer(writer, (DataWriter*)INCREF(hl_writer));
}

void
Arch_register_deletions_writer(Architecture *self, SegWriter *writer)
{
    Snapshot   *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment    *segment    = SegWriter_Get_Segment(writer);
    PolyReader *polyreader = SegWriter_Get_PolyReader(writer);
    DefaultDeletionsWriter *del_writer 
        = DefDelWriter_new(snapshot, segment, polyreader);
    UNUSED_VAR(self);
    SegWriter_Register(writer, DELETIONSWRITER.name, (DataWriter*)del_writer);
    SegWriter_Set_Del_Writer(writer, (DeletionsWriter*)del_writer);
}

void
Arch_init_seg_reader(Architecture *self, SegReader *reader)
{
    Arch_Register_Doc_Reader(self, reader);
    Arch_Register_Lexicon_Reader(self, reader);
    Arch_Register_Postings_Reader(self, reader);
    Arch_Register_Sort_Reader(self, reader);
    Arch_Register_Highlight_Reader(self, reader);
    Arch_Register_Deletions_Reader(self, reader);
}

void
Arch_register_doc_reader(Architecture *self, SegReader *reader)
{
    Schema     *schema   = SegReader_Get_Schema(reader);
    Folder     *folder   = SegReader_Get_Folder(reader);
    VArray     *segments = SegReader_Get_Segments(reader);
    Snapshot   *snapshot = SegReader_Get_Snapshot(reader);
    i32_t       seg_tick = SegReader_Get_Seg_Tick(reader);
    DefaultDocReader *doc_reader 
        = DefDocReader_new(schema, folder, snapshot, segments, seg_tick);
    UNUSED_VAR(self);
    SegReader_Register(reader, DOCREADER.name, (DataReader*)doc_reader);
}

void
Arch_register_postings_reader(Architecture *self, SegReader *reader)
{
    Schema    *schema   = SegReader_Get_Schema(reader);
    Folder    *folder   = SegReader_Get_Folder(reader);
    VArray    *segments = SegReader_Get_Segments(reader);
    Snapshot  *snapshot = SegReader_Get_Snapshot(reader);
    i32_t      seg_tick = SegReader_Get_Seg_Tick(reader);
    LexiconReader *lex_reader 
        = (LexiconReader*)SegReader_Obtain(reader, LEXICONREADER.name);
    DefaultPostingsReader *post_reader = DefPostReader_new(schema, folder, 
        snapshot, segments, seg_tick, lex_reader);
    UNUSED_VAR(self);
    SegReader_Register(reader, POSTINGSREADER.name, (DataReader*)post_reader);
}

void
Arch_register_lexicon_reader(Architecture *self, SegReader *reader)
{
    Schema    *schema   = SegReader_Get_Schema(reader);
    Folder    *folder   = SegReader_Get_Folder(reader);
    VArray    *segments = SegReader_Get_Segments(reader);
    Snapshot  *snapshot = SegReader_Get_Snapshot(reader);
    i32_t      seg_tick = SegReader_Get_Seg_Tick(reader);
    DefaultLexiconReader *lex_reader 
        = DefLexReader_new(schema, folder, snapshot, segments, seg_tick);
    UNUSED_VAR(self);
    SegReader_Register(reader, LEXICONREADER.name, (DataReader*)lex_reader);
}

void
Arch_register_sort_reader(Architecture *self, SegReader *reader)
{
    Schema     *schema   = SegReader_Get_Schema(reader);
    Folder     *folder   = SegReader_Get_Folder(reader);
    VArray     *segments = SegReader_Get_Segments(reader);
    Snapshot   *snapshot = SegReader_Get_Snapshot(reader);
    i32_t       seg_tick = SegReader_Get_Seg_Tick(reader);
    DefaultSortReader *sort_reader 
        = DefSortReader_new(schema, folder, snapshot, segments, seg_tick);
    UNUSED_VAR(self);
    SegReader_Register(reader, SORTREADER.name, (DataReader*)sort_reader);
}

void
Arch_register_highlight_reader(Architecture *self, SegReader *reader)
{
    Schema     *schema   = SegReader_Get_Schema(reader);
    Folder     *folder   = SegReader_Get_Folder(reader);
    VArray     *segments = SegReader_Get_Segments(reader);
    Snapshot   *snapshot = SegReader_Get_Snapshot(reader);
    i32_t       seg_tick = SegReader_Get_Seg_Tick(reader);
    DefaultHighlightReader* hl_reader
        = DefHLReader_new(schema, folder, snapshot, segments, seg_tick);
    UNUSED_VAR(self);
    SegReader_Register(reader, HIGHLIGHTREADER.name, (DataReader*)hl_reader);
}

void
Arch_register_deletions_reader(Architecture *self, SegReader *reader)
{
    Schema     *schema   = SegReader_Get_Schema(reader);
    Folder     *folder   = SegReader_Get_Folder(reader);
    VArray     *segments = SegReader_Get_Segments(reader);
    Snapshot   *snapshot = SegReader_Get_Snapshot(reader);
    i32_t       seg_tick = SegReader_Get_Seg_Tick(reader);
    DefaultDeletionsReader* del_reader
        = DefDelReader_new(schema, folder, snapshot, segments, seg_tick);
    UNUSED_VAR(self);
    SegReader_Register(reader, DELETIONSREADER.name, (DataReader*)del_reader);
}

Similarity*
Arch_make_similarity(Architecture *self)
{
    UNUSED_VAR(self);
    return Sim_new();
}

i32_t
Arch_index_interval(Architecture *self) 
{
    UNUSED_VAR(self);
    return 128;
}

i32_t
Arch_skip_interval(Architecture *self) 
{
    UNUSED_VAR(self);
    return 16;
}

/* Copyright 2008-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

