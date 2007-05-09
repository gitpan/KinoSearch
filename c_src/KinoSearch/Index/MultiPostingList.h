#ifndef H_KINO_MULTIPOSTINGLIST
#define H_KINO_MULTIPOSTINGLIST 1

#include "KinoSearch/Index/PostingList.r"

struct kino_SegPostingList;

typedef struct kino_MultiPostingList kino_MultiPostingList;
typedef struct KINO_MULTIPOSTINGLIST_VTABLE KINO_MULTIPOSTINGLIST_VTABLE;

KINO_CLASS("KinoSearch::Index::MultiPostingList", "MultiPList", 
    "KinoSearch::Index::PostingList");

struct kino_MultiPostingList {
    KINO_MULTIPOSTINGLIST_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_ByteBuf        *field;
    struct kino_VArray         *sub_plists;
    struct kino_SegPostingList *current;
    chy_u32_t                   num_subs;
    chy_u32_t                   tick;
};

/* Constructor.
 */
kino_MultiPostingList*
kino_MultiPList_new(const struct kino_ByteBuf *field, 
                    struct kino_VArray *sub_plists, 
                    struct kino_VArray *starts);

void 
kino_MultiPList_destroy(kino_MultiPostingList *self);
KINO_METHOD("Kino_MultiPList_Destroy");

struct kino_Posting*
kino_MultiPList_get_posting(kino_MultiPostingList *self);
KINO_METHOD("Kino_MultiPList_Get_Posting");

chy_u32_t
kino_MultiPList_get_doc_freq(kino_MultiPostingList *self);
KINO_METHOD("Kino_MultiPList_Get_Doc_Freq");

chy_u32_t
kino_MultiPList_get_doc_num(kino_MultiPostingList *self);
KINO_METHOD("Kino_MultiPList_Get_Doc_Num");

chy_u32_t 
kino_MultiPList_bulk_read(kino_MultiPostingList *self, 
                          struct kino_ByteBuf *postings, 
                          chy_u32_t num_wanted);
KINO_METHOD("Kino_MultiPList_Bulk_Read");

chy_bool_t
kino_MultiPList_next(kino_MultiPostingList *self);
KINO_METHOD("Kino_MultiPList_Next");

void
kino_MultiPList_seek(kino_MultiPostingList *self, struct kino_Term *target);
KINO_METHOD("Kino_MultiPList_Seek");

chy_bool_t
kino_MultiPList_skip_to(kino_MultiPostingList *self, chy_u32_t target);
KINO_METHOD("Kino_MultiPList_Skip_To");

struct kino_Scorer*
kino_MultiPList_make_scorer(kino_MultiPostingList *self, 
                            struct kino_Similarity *sim,
                            void *weight, float weight_val);
KINO_METHOD("Kino_MultiPList_Make_Scorer");

KINO_END_CLASS

#endif /* H_KINO_MULTIPOSTINGLIST */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

