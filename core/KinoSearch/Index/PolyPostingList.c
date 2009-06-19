#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/PolyPostingList.h"
#include "KinoSearch/Posting.h"
#include "KinoSearch/Index/PostingsReader.h"
#include "KinoSearch/Index/SegPostingList.h"
#include "KinoSearch/Search/Compiler.h"
#include "KinoSearch/Search/Matcher.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Util/I32Array.h"

PolyPostingList*
PolyPList_new(const CharBuf *field, VArray *readers, I32Array *starts)
{
    PolyPostingList *self 
        = (PolyPostingList*)VTable_Make_Obj(&POLYPOSTINGLIST);
    return PolyPList_init(self, field, readers, starts);
}

PolyPostingList*
PolyPList_init(PolyPostingList *self, const CharBuf *field, 
                VArray *readers, I32Array *starts)
{
    u32_t i;
    const u32_t num_readers = VA_Get_Size(readers);

    /* Init. */
    self->tick            = 0;
    self->current         = NULL;

    /* Assign. */
    self->field           = CB_Clone(field);

    /* Get sub-posting_lists and assign offsets. */
    self->sub_plists = VA_new(num_readers);
    for (i = 0; i < num_readers; i++) {
        PostingsReader *const post_reader = (PostingsReader*)ASSERT_IS_A(
            VA_Fetch(readers, i), POSTINGSREADER);
        i32_t offset = I32Arr_Get(starts, i);
        SegPostingList *sub_plist = (SegPostingList*)PostReader_Posting_List(
            post_reader, field, NULL);

        if (sub_plist) {
            ASSERT_IS_A(sub_plist, SEGPOSTINGLIST);
            SegPList_Set_Doc_Base(sub_plist, offset);
            VA_Push(self->sub_plists, (Obj*)sub_plist);
        }
    }
    self->num_subs = VA_Get_Size(self->sub_plists);

    return self;
}

void
PolyPList_destroy(PolyPostingList* self) 
{
    DECREF(self->sub_plists);
    DECREF(self->field);
    SUPER_DESTROY(self, POLYPOSTINGLIST);
}

void
PolyPList_seek(PolyPostingList *self, Obj *target)
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
PolyPList_get_doc_freq(PolyPostingList *self) 
{
    u32_t i;
    u32_t doc_freq = 0;

    /* Sum the doc_freqs of all segments. */
    for (i = 0; i < self->num_subs; i++) {
        SegPostingList *const sub_plist 
            = (SegPostingList*)VA_Fetch(self->sub_plists, i);
        doc_freq += SegPList_Get_Doc_Freq(sub_plist);
    }
    return doc_freq;
}

Posting*
PolyPList_get_posting(PolyPostingList *self) 
{
    return SegPList_Get_Posting(self->current);
}

i32_t
PolyPList_get_doc_id(PolyPostingList *self) 
{
    return SegPList_Get_Doc_ID(self->current);
}

i32_t
PolyPList_next(PolyPostingList* self) 
{
    while (1) {
        /* Try current segment. */
        if (self->current != NULL) {
            i32_t doc_id = SegPList_Next(self->current);
            if (doc_id != 0) {
                return doc_id;
            }
        }

        /* Advance to next segment, or bail if we're out of segments. */
        if (self->tick < self->num_subs) {
            self->current = (SegPostingList*)VA_Fetch(self->sub_plists,
                self->tick);
            self->tick++;
        }
        else {
            return 0;
        }
    }
}

i32_t 
PolyPList_advance(PolyPostingList *self, i32_t target)
{
    while (1) {
        /* Try current segment. */
        if (self->current != NULL) {
            i32_t doc_id = SegPList_Advance(self->current, target);
            if (doc_id != 0) {
                return doc_id;
            }
        }

        /* Advance to next segment, or bail if we're out of segments. */
        if (self->tick < self->num_subs) {
            self->current = (SegPostingList*)VA_Fetch(self->sub_plists,
                self->tick);
            self->tick++;
        }
        else {
            return 0;
        }
    }
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

