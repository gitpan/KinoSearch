#define C_KINO_ARCHITECTURE
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Plan/Architecture.h"
#include "KinoSearch/Index/DeletionsReader.h"
#include "KinoSearch/Index/DeletionsWriter.h"
#include "KinoSearch/Index/DocReader.h"
#include "KinoSearch/Index/DocWriter.h"
#include "KinoSearch/Index/HighlightReader.h"
#include "KinoSearch/Index/HighlightWriter.h"
#include "KinoSearch/Index/LexiconReader.h"
#include "KinoSearch/Index/LexiconWriter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/PostingListReader.h"
#include "KinoSearch/Index/PostingListWriter.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/SegWriter.h"
#include "KinoSearch/Index/Similarity.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Index/SortReader.h"
#include "KinoSearch/Index/SortWriter.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Store/Folder.h"

Architecture*
Arch_new()
{
    Architecture *self = (Architecture*)VTable_Make_Obj(ARCHITECTURE);
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
    if (!Obj_Is_A(other, ARCHITECTURE)) return false;
    return true;
}

void
Arch_init_seg_writer(Architecture *self, SegWriter *writer)
{
    Arch_Register_Lexicon_Writer(self, writer);
    Arch_Register_Posting_List_Writer(self, writer);
    Arch_Register_Sort_Writer(self, writer);
    Arch_Register_Doc_Writer(self, writer);
    Arch_Register_Highlight_Writer(self, writer);
    Arch_Register_Deletions_Writer(self, writer);
}

void
Arch_register_lexicon_writer(Architecture *self, SegWriter *writer)
{
    Schema        *schema     = SegWriter_Get_Schema(writer);
    Snapshot      *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment       *segment    = SegWriter_Get_Segment(writer);
    PolyReader    *polyreader = SegWriter_Get_PolyReader(writer);
    LexiconWriter *lex_writer 
        = LexWriter_new(schema, snapshot, segment, polyreader);
    UNUSED_VAR(self);
    SegWriter_Register(writer, VTable_Get_Name(LEXICONWRITER),
        (DataWriter*)lex_writer);
}

void
Arch_register_posting_list_writer(Architecture *self, SegWriter *writer)
{
    Schema        *schema     = SegWriter_Get_Schema(writer);
    Snapshot      *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment       *segment    = SegWriter_Get_Segment(writer);
    PolyReader    *polyreader = SegWriter_Get_PolyReader(writer);
    LexiconWriter *lex_writer = (LexiconWriter*)SegWriter_Fetch(writer, 
        VTable_Get_Name(LEXICONWRITER));
    UNUSED_VAR(self);
    if (!lex_writer) {
        THROW(ERR, "Can't fetch a LexiconWriter");
    }
    else {
        PostingListWriter *plist_writer = PListWriter_new(schema, snapshot,
            segment, polyreader, lex_writer);
        SegWriter_Register(writer, VTable_Get_Name(POSTINGLISTWRITER), 
            (DataWriter*)plist_writer);
        SegWriter_Add_Writer(writer, (DataWriter*)INCREF(plist_writer));
    }
}

void
Arch_register_doc_writer(Architecture *self, SegWriter *writer)
{
    Schema     *schema     = SegWriter_Get_Schema(writer);
    Snapshot   *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment    *segment    = SegWriter_Get_Segment(writer);
    PolyReader *polyreader = SegWriter_Get_PolyReader(writer);
    DocWriter  *doc_writer 
        = DocWriter_new(schema, snapshot, segment, polyreader);
    UNUSED_VAR(self);
    SegWriter_Register(writer, VTable_Get_Name(DOCWRITER), 
        (DataWriter*)doc_writer);
    SegWriter_Add_Writer(writer, (DataWriter*)INCREF(doc_writer));
}

void
Arch_register_sort_writer(Architecture *self, SegWriter *writer)
{
    Schema     *schema     = SegWriter_Get_Schema(writer);
    Snapshot   *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment    *segment    = SegWriter_Get_Segment(writer);
    PolyReader *polyreader = SegWriter_Get_PolyReader(writer);
    SortWriter *sort_writer 
        = SortWriter_new(schema, snapshot, segment, polyreader);
    UNUSED_VAR(self);
    SegWriter_Register(writer, VTable_Get_Name(SORTWRITER), 
        (DataWriter*)sort_writer);
    SegWriter_Add_Writer(writer, (DataWriter*)INCREF(sort_writer));
}

void
Arch_register_highlight_writer(Architecture *self, SegWriter *writer)
{
    Schema     *schema     = SegWriter_Get_Schema(writer);
    Snapshot   *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment    *segment    = SegWriter_Get_Segment(writer);
    PolyReader *polyreader = SegWriter_Get_PolyReader(writer);
    HighlightWriter *hl_writer
        = HLWriter_new(schema, snapshot, segment, polyreader);
    UNUSED_VAR(self);
    SegWriter_Register(writer, VTable_Get_Name(HIGHLIGHTWRITER), 
        (DataWriter*)hl_writer);
    SegWriter_Add_Writer(writer, (DataWriter*)INCREF(hl_writer));
}

void
Arch_register_deletions_writer(Architecture *self, SegWriter *writer)
{
    Schema     *schema     = SegWriter_Get_Schema(writer);
    Snapshot   *snapshot   = SegWriter_Get_Snapshot(writer);
    Segment    *segment    = SegWriter_Get_Segment(writer);
    PolyReader *polyreader = SegWriter_Get_PolyReader(writer);
    DefaultDeletionsWriter *del_writer 
        = DefDelWriter_new(schema, snapshot, segment, polyreader);
    UNUSED_VAR(self);
    SegWriter_Register(writer, VTable_Get_Name(DELETIONSWRITER), 
        (DataWriter*)del_writer);
    SegWriter_Set_Del_Writer(writer, (DeletionsWriter*)del_writer);
}

void
Arch_init_seg_reader(Architecture *self, SegReader *reader)
{
    Arch_Register_Doc_Reader(self, reader);
    Arch_Register_Lexicon_Reader(self, reader);
    Arch_Register_Posting_List_Reader(self, reader);
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
    int32_t     seg_tick = SegReader_Get_Seg_Tick(reader);
    DefaultDocReader *doc_reader 
        = DefDocReader_new(schema, folder, snapshot, segments, seg_tick);
    UNUSED_VAR(self);
    SegReader_Register(reader, VTable_Get_Name(DOCREADER), 
        (DataReader*)doc_reader);
}

void
Arch_register_posting_list_reader(Architecture *self, SegReader *reader)
{
    Schema    *schema   = SegReader_Get_Schema(reader);
    Folder    *folder   = SegReader_Get_Folder(reader);
    VArray    *segments = SegReader_Get_Segments(reader);
    Snapshot  *snapshot = SegReader_Get_Snapshot(reader);
    int32_t    seg_tick = SegReader_Get_Seg_Tick(reader);
    LexiconReader *lex_reader = (LexiconReader*)SegReader_Obtain(reader, 
        VTable_Get_Name(LEXICONREADER));
    DefaultPostingListReader *plist_reader = DefPListReader_new(schema, folder, 
        snapshot, segments, seg_tick, lex_reader);
    UNUSED_VAR(self);
    SegReader_Register(reader, VTable_Get_Name(POSTINGLISTREADER), 
        (DataReader*)plist_reader);
}

void
Arch_register_lexicon_reader(Architecture *self, SegReader *reader)
{
    Schema    *schema   = SegReader_Get_Schema(reader);
    Folder    *folder   = SegReader_Get_Folder(reader);
    VArray    *segments = SegReader_Get_Segments(reader);
    Snapshot  *snapshot = SegReader_Get_Snapshot(reader);
    int32_t    seg_tick = SegReader_Get_Seg_Tick(reader);
    DefaultLexiconReader *lex_reader 
        = DefLexReader_new(schema, folder, snapshot, segments, seg_tick);
    UNUSED_VAR(self);
    SegReader_Register(reader, VTable_Get_Name(LEXICONREADER), 
        (DataReader*)lex_reader);
}

void
Arch_register_sort_reader(Architecture *self, SegReader *reader)
{
    Schema     *schema   = SegReader_Get_Schema(reader);
    Folder     *folder   = SegReader_Get_Folder(reader);
    VArray     *segments = SegReader_Get_Segments(reader);
    Snapshot   *snapshot = SegReader_Get_Snapshot(reader);
    int32_t     seg_tick = SegReader_Get_Seg_Tick(reader);
    DefaultSortReader *sort_reader 
        = DefSortReader_new(schema, folder, snapshot, segments, seg_tick);
    UNUSED_VAR(self);
    SegReader_Register(reader, VTable_Get_Name(SORTREADER), 
        (DataReader*)sort_reader);
}

void
Arch_register_highlight_reader(Architecture *self, SegReader *reader)
{
    Schema     *schema   = SegReader_Get_Schema(reader);
    Folder     *folder   = SegReader_Get_Folder(reader);
    VArray     *segments = SegReader_Get_Segments(reader);
    Snapshot   *snapshot = SegReader_Get_Snapshot(reader);
    int32_t     seg_tick = SegReader_Get_Seg_Tick(reader);
    DefaultHighlightReader* hl_reader
        = DefHLReader_new(schema, folder, snapshot, segments, seg_tick);
    UNUSED_VAR(self);
    SegReader_Register(reader, VTable_Get_Name(HIGHLIGHTREADER), 
        (DataReader*)hl_reader);
}

void
Arch_register_deletions_reader(Architecture *self, SegReader *reader)
{
    Schema     *schema   = SegReader_Get_Schema(reader);
    Folder     *folder   = SegReader_Get_Folder(reader);
    VArray     *segments = SegReader_Get_Segments(reader);
    Snapshot   *snapshot = SegReader_Get_Snapshot(reader);
    int32_t     seg_tick = SegReader_Get_Seg_Tick(reader);
    DefaultDeletionsReader* del_reader
        = DefDelReader_new(schema, folder, snapshot, segments, seg_tick);
    UNUSED_VAR(self);
    SegReader_Register(reader, VTable_Get_Name(DELETIONSREADER), 
        (DataReader*)del_reader);
}

Similarity*
Arch_make_similarity(Architecture *self)
{
    UNUSED_VAR(self);
    return Sim_new();
}

int32_t
Arch_index_interval(Architecture *self) 
{
    UNUSED_VAR(self);
    return 128;
}

int32_t
Arch_skip_interval(Architecture *self) 
{
    UNUSED_VAR(self);
    return 16;
}

/* Copyright 2008-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

