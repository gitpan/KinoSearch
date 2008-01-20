#ifndef H_KINO_SEGPOSTINGLIST
#define H_KINO_SEGPOSTINGLIST 1

#include "KinoSearch/Index/PostingList.r"

typedef struct kino_SegPostingList kino_SegPostingList;
typedef struct KINO_SEGPOSTINGLIST_VTABLE KINO_SEGPOSTINGLIST_VTABLE;

struct kino_Schema;
struct kino_Folder;
struct kino_SegInfo;
struct kino_FieldSpec;
struct kino_InStream;
struct kino_DelDocs;
struct kino_SkipStepper;
struct kino_TermInfo;
struct kino_LexReader;
struct kino_VArray;

KINO_CLASS("KinoSearch::Index::SegPostingList", "SegPList", 
    "KinoSearch::Index::PostingList");

struct kino_SegPostingList {
    KINO_SEGPOSTINGLIST_VTABLE *_;
    KINO_POSTINGLIST_MEMBER_VARS;
    struct kino_Schema         *schema;
    struct kino_Folder         *folder;
    struct kino_SegInfo        *seg_info;
    struct kino_DelDocs        *deldocs;
    struct kino_ByteBuf        *field;
    struct kino_LexReader      *lex_reader;
    struct kino_Posting        *posting;
    struct kino_InStream       *post_stream;
    struct kino_InStream       *skip_stream;
    struct kino_SkipStepper    *skip_stepper;
    chy_u32_t                   doc_base;
    chy_u32_t                   count;
    chy_u32_t                   doc_freq;
    chy_u32_t                   skip_count;
    chy_u32_t                   num_skips;
    chy_i32_t                   field_num;
    chy_u32_t                   skip_interval;
};

/* Constructor.
 */
kino_SegPostingList*
kino_SegPList_new(struct kino_Schema *schema, 
                  struct kino_Folder *folder, 
                  struct kino_SegInfo *seg_info, 
                  const struct kino_ByteBuf *field,
                  struct kino_LexReader *lex_reader, 
                  struct kino_DelDocs *deldocs, 
                  chy_u32_t skip_interval);

/* Set a base which will be added to the document number of all postings.
 * 
 * This should not be called after Seek.
 */
void
kino_SegPList_set_doc_base(kino_SegPostingList *self, chy_u32_t doc_base);
KINO_METHOD("Kino_SegPList_Set_Doc_Base");

void 
kino_SegPList_destroy(kino_SegPostingList *self);
KINO_METHOD("Kino_SegPList_Destroy");

chy_u32_t
kino_SegPList_get_doc_freq(kino_SegPostingList *self);
KINO_METHOD("Kino_SegPList_Get_Doc_Freq");

chy_u32_t
kino_SegPList_get_doc_num(kino_SegPostingList *self);
KINO_METHOD("Kino_SegPList_Get_Doc_Num");

struct kino_Posting*
kino_SegPList_get_posting(kino_SegPostingList *self);
KINO_METHOD("Kino_SegPList_Get_Posting");

chy_bool_t
kino_SegPList_next(kino_SegPostingList *self);
KINO_METHOD("Kino_SegPList_Next");

/*
chy_bool_t
kino_SegPList_skip_to(kino_SegPostingList *self, chy_u32_t target);
KINO_METHOD("Kino_SegPList_Skip_To");
*/

void
kino_SegPList_seek(kino_SegPostingList *self, struct kino_Term *target);
KINO_METHOD("Kino_SegPList_Seek");

void
kino_SegPList_seek_lex(kino_SegPostingList *self, 
                      struct kino_Lexicon *lexicon);
KINO_METHOD("Kino_SegPList_Seek_Lex");

struct kino_Scorer*
kino_SegPList_make_scorer(kino_SegPostingList *self, 
                          struct kino_Similarity *sim,
                          void *weight, float weight_val);
KINO_METHOD("Kino_SegPList_Make_Scorer");

KINO_END_CLASS

#endif /* H_KINO_SEGPOSTINGLIST */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

