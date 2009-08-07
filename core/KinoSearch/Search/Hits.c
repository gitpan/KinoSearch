#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/Hits.h"
#include "KinoSearch/Doc/HitDoc.h"
#include "KinoSearch/Search/Query.h"
#include "KinoSearch/Search/MatchDoc.h"
#include "KinoSearch/Search/Searchable.h"
#include "KinoSearch/Search/TopDocs.h"

Hits*
Hits_new(Searchable *searchable, TopDocs *top_docs, u32_t offset)
{
    Hits *self = (Hits*)VTable_Make_Obj(HITS);
    return Hits_init(self, searchable, top_docs, offset);
}

Hits*
Hits_init(Hits *self, Searchable *searchable, TopDocs *top_docs, u32_t offset)
{
    self->searchable = (Searchable*)INCREF(searchable);
    self->top_docs   = (TopDocs*)INCREF(top_docs);
    self->offset     = offset;
    return self;
}

void
Hits_destroy(Hits *self)
{
    DECREF(self->searchable);
    DECREF(self->top_docs);
    FREE_OBJ(self);
}

Obj*
Hits_next(Hits *self)
{
    MatchDoc *match_doc 
        = (MatchDoc*)VA_Fetch(self->top_docs->match_docs, self->offset);
    self->offset++;

    if (!match_doc) {
        /** Bail if there aren't any more *captured* hits. (There may be more
         * total hits.) */
        return NULL;
    }
    else {
        /* Lazily fetch HitDoc, set score. */
        Obj *doc = Searchable_Fetch_Doc(self->searchable,
            match_doc->doc_id, match_doc->score, 0);

        return doc;
    }
}

u32_t
Hits_total_hits(Hits *self)
{
    return TopDocs_Get_Total_Hits(self->top_docs);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

