#define C_KINO_SEARCHER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/Searcher.h"

#include "KinoSearch/Index/DocVector.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Search/Collector.h"
#include "KinoSearch/Search/Hits.h"
#include "KinoSearch/Search/NoMatchQuery.h"
#include "KinoSearch/Search/Query.h"
#include "KinoSearch/Search/QueryParser.h"
#include "KinoSearch/Search/SortSpec.h"
#include "KinoSearch/Search/TopDocs.h"
#include "KinoSearch/Search/Compiler.h"

Searcher*
Searcher_init(Searcher *self, Schema *schema)
{
    self->schema  = (Schema*)INCREF(schema);
    self->qparser = NULL;
    ABSTRACT_CLASS_CHECK(self, SEARCHER);
    return self;
}

void
Searcher_destroy(Searcher *self)
{
    DECREF(self->schema);
    DECREF(self->qparser);
    SUPER_DESTROY(self, SEARCHER);
}

Hits*
Searcher_hits(Searcher *self, Obj *query, uint32_t offset, uint32_t num_wanted, 
              SortSpec *sort_spec)
{
    Query   *real_query = Searcher_Glean_Query(self, query);
    TopDocs *top_docs   = Searcher_Top_Docs(self, real_query, 
                                offset + num_wanted, sort_spec);
    Hits    *hits       = Hits_new(self, top_docs, offset);
    DECREF(top_docs);
    DECREF(real_query);
    return hits;
}

Query*
Searcher_glean_query(Searcher *self, Obj *query)
{
    Query *real_query = NULL;

    if (!query) {
        real_query = (Query*)NoMatchQuery_new();
    }
    else if (Obj_Is_A(query, QUERY)) {
        real_query = (Query*)INCREF(query);
    }
    else if (Obj_Is_A(query, CHARBUF)) {
        if (!self->qparser) 
            self->qparser = QParser_new(self->schema, NULL, NULL, NULL);
        real_query = QParser_Parse(self->qparser, (CharBuf*)query);
    }
    else {
        THROW(ERR, "Invalid type for 'query' param: %o",
            Obj_Get_Class_Name(query));
    }

    return real_query;
}

Schema*
Searcher_get_schema(Searcher *self)
{
    return self->schema;
}

void
Searcher_close(Searcher *self)
{
    UNUSED_VAR(self);
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

