#define C_KINO_POLYSEARCHER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/PolySearcher.h"

#include "KinoSearch/Doc/HitDoc.h"
#include "KinoSearch/Index/DocVector.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Search/HitCollector.h"
#include "KinoSearch/Search/HitQueue.h"
#include "KinoSearch/Search/Query.h"
#include "KinoSearch/Search/MatchDoc.h"
#include "KinoSearch/Search/Matcher.h"
#include "KinoSearch/Search/Searchable.h"
#include "KinoSearch/Search/SortSpec.h"
#include "KinoSearch/Search/TopDocs.h"
#include "KinoSearch/Search/Compiler.h"
#include "KinoSearch/Searcher.h"

PolySearcher*
PolySearcher_init(PolySearcher *self, Schema *schema, VArray *searchables)
{
    const u32_t num_searchables = VA_Get_Size(searchables);
    u32_t i;
    i32_t *starts_array = (i32_t*)MALLOCATE(num_searchables * sizeof(i32_t));
    i32_t doc_max = 0;

    Searchable_init((Searchable*)self, schema);
    self->searchables = (VArray*)INCREF(searchables);
    self->starts = NULL; /* Safe cleanup. */

    for (i = 0; i < num_searchables; i++) {
        Searchable *searchable 
            = (Searchable*)CERTIFY(VA_Fetch(searchables, i), SEARCHABLE);
        Schema *candidate    = Searchable_Get_Schema(searchable);
        VTable *orig_vt      = Schema_Get_VTable(schema);
        VTable *candidate_vt = Schema_Get_VTable(candidate);

        /* Confirm that searchables all use the same schema. */
        if (orig_vt != candidate_vt) {
            THROW(ERR, "Conflicting schemas: '%o', '%o'",
                Schema_Get_Class_Name(schema), 
                Schema_Get_Class_Name(candidate));
        }

        /* Derive doc_max and relative start offsets. */
        starts_array[i] = (i32_t)doc_max;
        doc_max += Searchable_Doc_Max(searchable);
    }

    self->doc_max = doc_max;
    self->starts  = I32Arr_new_steal(starts_array, num_searchables);

    return self;
}

void
PolySearcher_destroy(PolySearcher *self)
{
    DECREF(self->searchables);
    DECREF(self->starts);
    SUPER_DESTROY(self, POLYSEARCHER);
}

Obj*
PolySearcher_fetch_doc(PolySearcher *self, i32_t doc_id, float score, 
                       i32_t offset)
{
    u32_t       tick       = PolyReader_sub_tick(self->starts, doc_id);
    Searchable *searchable = (Searchable*)VA_Fetch(self->searchables, tick);
    i32_t       start      = I32Arr_Get(self->starts, tick);
    if (!searchable) { THROW(ERR, "Invalid doc id: %i32", doc_id); }
    return Searchable_Fetch_Doc(searchable, doc_id - start, score, 
        offset + start);
}

DocVector*
PolySearcher_fetch_doc_vec(PolySearcher *self, i32_t doc_id)
{
    u32_t       tick       = PolyReader_sub_tick(self->starts, doc_id);
    Searchable *searchable = (Searchable*)VA_Fetch(self->searchables, tick);
    i32_t       start      = I32Arr_Get(self->starts, tick);
    if (!searchable) { THROW(ERR, "Invalid doc id: %i32", doc_id); }
    return Searchable_Fetch_Doc_Vec(searchable, doc_id - start);
}

i32_t 
PolySearcher_doc_max(PolySearcher *self)
{
    return self->doc_max;
}

u32_t
PolySearcher_doc_freq(PolySearcher *self, const CharBuf *field, Obj *term)
{
    u32_t i, max; 
    u32_t doc_freq = 0;
    for (i = 0, max = VA_Get_Size(self->searchables); i < max; i++) {
        Searchable *searchable = (Searchable*)VA_Fetch(self->searchables, i);
        doc_freq += Searchable_Doc_Freq(searchable, field, term);
    }
    return doc_freq;
}

static void
S_modify_doc_ids(VArray *match_docs, i32_t base)
{
    u32_t i, max;
    for (i = 0, max = VA_Get_Size(match_docs); i < max; i++) {
        MatchDoc *match_doc = (MatchDoc*)VA_Fetch(match_docs, i);
        i32_t new_doc_id = MatchDoc_Get_Doc_ID(match_doc) + base;
        MatchDoc_Set_Doc_ID(match_doc, new_doc_id);
    }
}

TopDocs*
PolySearcher_top_docs(PolySearcher *self, Query *query, u32_t num_wanted,
                      SortSpec *sort_spec)
{
    Schema   *schema      = PolySearcher_Get_Schema(self);
    VArray   *searchables = self->searchables;
    I32Array *starts      = self->starts;
    HitQueue *hit_q       = sort_spec 
                          ? HitQ_new(schema, sort_spec, num_wanted)
                          : HitQ_new(NULL, NULL, num_wanted);
    u32_t     total_hits  = 0;
    Compiler *compiler    = Query_Is_A(query, COMPILER) 
                          ? ((Compiler*)INCREF(query))
                          : Query_Make_Compiler(query, (Searchable*)self,
                                Query_Get_Boost(query));
    u32_t i, max;

    for (i = 0, max = VA_Get_Size(searchables); i < max; i++) {
        Searchable *searchable = (Searchable*)VA_Fetch(searchables, i);
        i32_t       base       = I32Arr_Get(starts, i);
        TopDocs    *top_docs   = Searchable_Top_Docs(searchable, 
            (Query*)compiler, num_wanted, sort_spec);
        VArray     *sub_match_docs = TopDocs_Get_Match_Docs(top_docs);
        u32_t j, jmax;

        total_hits += TopDocs_Get_Total_Hits(top_docs);

        S_modify_doc_ids(sub_match_docs, base);
        for (j = 0, jmax = VA_Get_Size(sub_match_docs); j < jmax; j++) {
            MatchDoc *match_doc = (MatchDoc*)VA_Fetch(sub_match_docs, j);
            if (!HitQ_Insert(hit_q, INCREF(match_doc))) { break; }
        }

        DECREF(top_docs);
    }

    {
        VArray  *match_docs = HitQ_Pop_All(hit_q);
        TopDocs *retval     = TopDocs_new(match_docs, total_hits);

        DECREF(match_docs);
        DECREF(compiler);
        DECREF(hit_q);
        return retval;
    }
}


void
PolySearcher_collect(PolySearcher *self, Query *query, 
                     HitCollector *collector)
{
    u32_t i, max;
    VArray *const searchables = self->searchables;
    I32Array *starts = self->starts;
    
    for (i = 0, max = VA_Get_Size(searchables); i < max; i++) {
        i32_t start = I32Arr_Get(starts, i);
        Searchable *searchable = (Searchable*)VA_Fetch(searchables, i);
        OffsetCollector *offset_coll = OffsetColl_new(collector, start);
        Searchable_Collect(searchable, query, (HitCollector*)offset_coll);
        DECREF(offset_coll);
    }
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

