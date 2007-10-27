#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_MULTIPOSTINGLIST_VTABLE
#include "KinoSearch/Index/MultiPostingList.r"

#include "KinoSearch/Posting.r"
#include "KinoSearch/Index/Term.r"
#include "KinoSearch/Index/SegPostingList.r"
#include "KinoSearch/Util/Int.r"

MultiPostingList*
MultiPList_new(const ByteBuf *field, VArray *sub_plists, VArray *starts)
{
    u32_t i;
    CREATE(self, MultiPostingList, MULTIPOSTINGLIST);

    /* init */
    self->tick            = 0;
    self->current         = NULL;
    
    /* assign */
    self->sub_plists      = REFCOUNT_INC(sub_plists);
    self->field           = BB_CLONE(field);

    /* derive */
    self->num_subs = sub_plists->size;

    /* assign offsets */
    for (i = 0; i < self->num_subs; i++) {
        SegPostingList *const sub_plist 
            = (SegPostingList*)VA_Fetch(sub_plists, i);
        Int *const offset = (Int*)VA_Fetch(starts, i);
        SegPList_Set_Doc_Base(sub_plist, offset->value);
    }
    
    return self;
}

void
MultiPList_destroy(MultiPostingList* self) 
{
    REFCOUNT_DEC(self->sub_plists);
    REFCOUNT_DEC(self->field);
    free(self);
}

void
MultiPList_seek(MultiPostingList *self, Term *target)
{
    u32_t i;
    for (i = 0; i < self->num_subs; i++) {
        SegPostingList *const sub_plist 
            = (SegPostingList*)VA_Fetch(self->sub_plists, i);
        SegPList_Seek(sub_plist, target);
    }
    self->tick     = 0;
    self->current  = NULL;
}

u32_t
MultiPList_get_doc_freq(MultiPostingList *self) 
{
    u32_t i;
    u32_t doc_freq = 0;

    /* sum the doc_freqs of all segments */
    for (i = 0; i < self->num_subs; i++) {
        SegPostingList *const sub_plist 
            = (SegPostingList*)VA_Fetch(self->sub_plists, i);
        doc_freq += SegPList_Get_Doc_Freq(sub_plist);
    }
    return doc_freq;
}

Posting*
MultiPList_get_posting(MultiPostingList *self) 
{
    return SegPList_Get_Posting(self->current);
}

u32_t
MultiPList_get_doc_num(MultiPostingList *self) 
{
    return SegPList_Get_Doc_Num(self->current);
}

bool_t
MultiPList_next(MultiPostingList* self) 
{
    while (1) {
        if (self->current != NULL && SegPList_Next(self->current) ) {
            return true;
        }
        else if (self->tick < self->num_subs) {
            /* try next segment */
            self->current = (SegPostingList*)VA_Fetch(self->sub_plists,
                self->tick);
            self->tick++;
        }
        else {
            /* done with all segments */
            return false;
        }
    }
}

bool_t 
MultiPList_skip_to(MultiPostingList *self, u32_t target)
{
    while (1) {
        if (   self->current != NULL 
            && SegPList_Skip_To(self->current, target)
        ) {
            return true;
        }
        else if (self->tick < self->num_subs) {
            /* try next segment */
            self->current = (SegPostingList*)VA_Fetch(self->sub_plists,
                self->tick);
            self->tick++;
        }
        else {
            return false;
        }
    }
}

struct kino_Scorer*
MultiPList_make_scorer(MultiPostingList *self, struct kino_Similarity *sim,
                       void *weight, float weight_val)
{
    SegPostingList *plist = (SegPostingList*)VA_Fetch(self->sub_plists, 0);
    Posting *posting      = SegPList_Get_Posting(plist);
    return Post_Make_Scorer(posting, sim, (PostingList*)self, 
        weight, weight_val);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

