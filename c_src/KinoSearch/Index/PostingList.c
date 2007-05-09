#include <string.h>

#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_POSTINGLIST_VTABLE
#include "KinoSearch/Index/PostingList.r"

#include "KinoSearch/Posting.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/Lexicon.r"
#include "KinoSearch/Util/ByteBuf.r"
#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/MemManager.h"

Posting*
PList_get_posting(PostingList *self) 
{
    ABSTRACT_DEATH(self, "Get_Posting");
    UNREACHABLE_RETURN(Posting*);
}

u32_t
PList_get_doc_freq(PostingList *self) 
{
    ABSTRACT_DEATH(self, "Get_Doc_Freq");
    UNREACHABLE_RETURN(u32_t);
}

u32_t
PList_get_doc_num(PostingList *self) 
{
    ABSTRACT_DEATH(self, "Get_Doc_Num");
    UNREACHABLE_RETURN(u32_t);
}

void
PList_seek(PostingList *self, Term *target) 
{
    UNUSED_VAR(target);
    ABSTRACT_DEATH(self, "Seek");
}

void
PList_seek_lex(PostingList *self, Lexicon *lexicon) 
{
    UNUSED_VAR(lexicon);
    ABSTRACT_DEATH(self, "Seek_Lex");
}

bool_t
PList_next(PostingList *self) 
{
    ABSTRACT_DEATH(self, "Next");
    UNREACHABLE_RETURN(bool_t);
}

u32_t  
PList_bulk_read(PostingList* self, ByteBuf *postings, u32_t num_wanted) 
{
    UNUSED_VAR(postings);
    ABSTRACT_DEATH(self, "Bulk_Read");
    UNREACHABLE_RETURN(u32_t);
}

bool_t
PList_skip_to(PostingList *self, u32_t target) 
{
    do {
        if ( !PList_Next(self) )
            return false;
    } while (target > (PList_Get_Posting(self))->doc_num);
    return true;
}

struct kino_Scorer*
PList_make_scorer(PostingList *self, struct kino_Similarity *sim, 
                  void *weight, float weight_val)
{
    UNUSED_VAR(sim);
    UNUSED_VAR(weight);
    UNUSED_VAR(weight_val);
    ABSTRACT_DEATH(self, "Make_Scorer");
    UNREACHABLE_RETURN(struct kino_Scorer*);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

