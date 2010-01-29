#define C_KINO_TERMSCORER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Search/TermScorer.h"
#include "KinoSearch/Posting.h"
#include "KinoSearch/Index/PostingList.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Search/Compiler.h"

TermScorer*
TermScorer_init(TermScorer *self, Similarity *similarity, PostingList *plist, 
                Compiler *compiler)
{
    Matcher_init((Matcher*)self);

    /* Assign. */
    self->sim           = (Similarity*)INCREF(similarity);
    self->plist         = (PostingList*)INCREF(plist);
    self->compiler      = (Compiler*)INCREF(compiler);
    self->weight        = Compiler_Get_Weight(compiler);

    /* Init. */
    self->posting        = NULL;

    return self;
}

void
TermScorer_destroy(TermScorer *self) 
{
    DECREF(self->sim);
    DECREF(self->plist);
    DECREF(self->compiler);
    SUPER_DESTROY(self, TERMSCORER);
}

i32_t
TermScorer_next(TermScorer* self) 
{
    PostingList *const plist = self->plist;
    if (plist) {
        i32_t doc_id = PList_Next(plist);
        if (doc_id) {
            self->posting = PList_Get_Posting(plist);
            return doc_id;
        }
        else {
            /* Reclaim resources a little early. */
            DECREF(plist);
            self->plist = NULL;
            return 0;
        }
    }
    return 0;
}

i32_t
TermScorer_advance(TermScorer *self, i32_t target)
{
    PostingList *const plist = self->plist;
    if (plist) {
        i32_t doc_id = PList_Advance(plist, target);
        if (doc_id) {
            self->posting = PList_Get_Posting(plist);
            return doc_id;
        }
        else {
            /* Reclaim resources a little early. */
            DECREF(plist);
            self->plist = NULL;
            return 0;
        }
    }
    return 0;
}

i32_t 
TermScorer_get_doc_id(TermScorer* self) 
{
    return Post_Get_Doc_ID(self->posting);
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

