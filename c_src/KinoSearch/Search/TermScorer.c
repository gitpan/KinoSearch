#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_TERMSCORER_VTABLE
#include "KinoSearch/Search/TermScorer.r"

#include "KinoSearch/Posting.r"
#include "KinoSearch/Index/PostingList.r"
#include "KinoSearch/Search/Similarity.r"
#include "KinoSearch/Search/ScoreProx.r"
#include "KinoSearch/Search/Tally.r"
#include "KinoSearch/Util/Native.r"

void
TermScorer_destroy(TermScorer *self) 
{
    REFCOUNT_DEC(self->sim);
    REFCOUNT_DEC(self->tally);
    REFCOUNT_DEC(self->sprox);
    REFCOUNT_DEC(self->plist);
    REFCOUNT_DEC(self->postings);
    REFCOUNT_DEC(self->weight);
    free(self->score_cache);
    free(self);
}

bool_t
TermScorer_next(TermScorer* self) 
{
    /* attempt to refill the postings blob if necessary */
    if (self->posting->next == NULL) {
        PList_Bulk_Read(self->plist, self->postings, 32);
        self->posting  = (Posting*)self->postings->ptr;

        /* check if we're done; reclaim resources a little early */
        if (self->posting->next == NULL) {
            REFCOUNT_DEC(self->plist);
            self->plist = NULL;

            return false;
        }
    }

    /* proceed to next posting */
    self->posting = self->posting->next;

    return true;
}

bool_t
TermScorer_skip_to(TermScorer *self, u32_t target)
{
    /* scan linked list */
    while (1) {
        if (   self->posting->doc_num >= target 
            && self->posting->doc_num != DOC_NUM_SENTINEL 
        ) {
            return true;
        }
        else if (self->posting->next != NULL) {
            self->posting = self->posting->next;
        }
        else {
            break;
        }
    }

    /* not in linked list, so skip posting list */
    if (PList_Skip_To(self->plist, target)) {
        self->posting = PList_Get_Posting(self->plist);
        return true;
    }
    else {
        return false;
    }
}

u32_t 
TermScorer_doc(TermScorer* self) 
{
    return self->posting->doc_num;
}

Tally*
TermScorer_tally(TermScorer* self) 
{
    return self->tally;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

