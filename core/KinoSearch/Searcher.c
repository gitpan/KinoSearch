#define C_KINO_SEARCHER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Searcher.h"

#include "KinoSearch/FieldType.h"
#include "KinoSearch/Index/DeletionsReader.h"
#include "KinoSearch/Index/DocReader.h"
#include "KinoSearch/Index/DocVector.h"
#include "KinoSearch/Index/IndexReader.h"
#include "KinoSearch/Index/LexiconReader.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/SortCache.h"
#include "KinoSearch/Index/HighlightReader.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Search/HitCollector.h"
#include "KinoSearch/Search/HitQueue.h"
#include "KinoSearch/Search/MatchDoc.h"
#include "KinoSearch/Search/Matcher.h"
#include "KinoSearch/Search/Query.h"
#include "KinoSearch/Search/HitCollector/SortCollector.h"
#include "KinoSearch/Search/SortRule.h"
#include "KinoSearch/Search/SortSpec.h"
#include "KinoSearch/Search/TopDocs.h"
#include "KinoSearch/Search/Compiler.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/FSFolder.h"
#include "KinoSearch/Util/I32Array.h"

Searcher*
Searcher_new(Obj *index)
{
    Searcher *self = (Searcher*)VTable_Make_Obj(SEARCHER);
    return Searcher_init(self, index);
}

Searcher*
Searcher_init(Searcher *self, Obj *index)
{
    if (OBJ_IS_A(index, INDEXREADER)) {
        self->reader = (IndexReader*)INCREF(index);
    }
    else {
        self->reader = IxReader_open(index, NULL, NULL);
    }
    Searchable_init((Searchable*)self, IxReader_Get_Schema(self->reader));
    self->seg_readers = IxReader_Seg_Readers(self->reader);
    self->seg_starts  = IxReader_Offsets(self->reader);
    self->doc_reader = (DocReader*)IxReader_Fetch(
        self->reader, VTable_Get_Name(DOCREADER));
    self->hl_reader = (HighlightReader*)IxReader_Fetch(
        self->reader, VTable_Get_Name(HIGHLIGHTREADER));
    if (self->doc_reader) { INCREF(self->doc_reader); }
    if (self->hl_reader)  { INCREF(self->hl_reader); }

    return self;
}

void
Searcher_destroy(Searcher *self)
{
    DECREF(self->reader);
    DECREF(self->doc_reader);
    DECREF(self->hl_reader);
    DECREF(self->seg_readers);
    DECREF(self->seg_starts);
    SUPER_DESTROY(self, SEARCHER);
}

Obj*
Searcher_fetch_doc(Searcher *self, i32_t doc_id, float score, i32_t offset)
{
    if (!self->doc_reader) { THROW(ERR, "No DocReader"); }
    return DocReader_Fetch(self->doc_reader, doc_id, score, offset);
}

DocVector*
Searcher_fetch_doc_vec(Searcher *self, i32_t doc_id)
{
    if (!self->hl_reader) { THROW(ERR, "No HighlightReader"); }
    return HLReader_Fetch(self->hl_reader, doc_id);
}

i32_t 
Searcher_doc_max(Searcher *self)
{
    return IxReader_Doc_Max(self->reader);
}

u32_t
Searcher_doc_freq(Searcher *self, const CharBuf *field, Obj *term)
{
    LexiconReader *lex_reader = (LexiconReader*)IxReader_Fetch(self->reader, 
        VTable_Get_Name(LEXICONREADER));
    return lex_reader ? LexReader_Doc_Freq(lex_reader, field, term) : 0;
}

TopDocs*
Searcher_top_docs(Searcher *self, Query *query, u32_t num_wanted, 
                  SortSpec *sort_spec)
{
    Schema        *schema    = Searcher_Get_Schema(self);
    SortCollector *collector = SortColl_new(schema, sort_spec, num_wanted);
    Searcher_Collect(self, query, (HitCollector*)collector);
    {
        VArray  *match_docs = SortColl_Pop_Match_Docs(collector);
        i32_t    total_hits = SortColl_Get_Total_Hits(collector);
        TopDocs *retval     = TopDocs_new(match_docs, total_hits);
        DECREF(collector);
        DECREF(match_docs);
        return retval;
    }
}

void
Searcher_collect(Searcher *self, Query *query, HitCollector *collector)
{
    u32_t i, max;
    VArray   *const seg_readers  = self->seg_readers;
    I32Array *const seg_starts   = self->seg_starts;
    bool_t    need_score         = HC_Need_Score(collector);
    Compiler *compiler = OBJ_IS_A(query, COMPILER)
                       ? (Compiler*)INCREF(query)
                       : Query_Make_Compiler(query, (Searchable*)self, 
                                             Query_Get_Boost(query));

    /* Accumulate hits into the HitCollector. */
    for (i = 0, max = VA_Get_Size(seg_readers); i < max; i++) {
        SegReader *seg_reader = (SegReader*)VA_Fetch(seg_readers, i);
        DeletionsReader *del_reader = (DeletionsReader*)SegReader_Fetch(
            seg_reader, VTable_Get_Name(DELETIONSREADER));
        Matcher *matcher 
            = Compiler_Make_Matcher(compiler, seg_reader, need_score);
        if (matcher) {
            i32_t seg_start = I32Arr_Get(seg_starts, i);
            Matcher *deletions = DelReader_Iterator(del_reader);
            HC_Set_Reader(collector, seg_reader);
            HC_Set_Base(collector, seg_start);
            HC_Set_Matcher(collector, matcher);
            Matcher_Collect(matcher, collector, deletions);
            DECREF(deletions);
            DECREF(matcher);
        }
    }

    DECREF(compiler);
}

IndexReader*
Searcher_get_reader(Searcher *self) { return self->reader; }

void
Searcher_close(Searcher *self)
{
    UNUSED_VAR(self);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

