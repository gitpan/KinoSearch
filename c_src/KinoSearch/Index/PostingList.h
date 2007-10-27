#ifndef H_KINO_POSTINGLIST
#define H_KINO_POSTINGLIST 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_PostingList kino_PostingList;
typedef struct KINO_POSTINGLIST_VTABLE KINO_POSTINGLIST_VTABLE;

struct kino_ByteBuf;
struct kino_Posting;
struct kino_Term;
struct kino_Lexicon;
struct kino_Similarity;

KINO_CLASS("KinoSearch::Index::PostingList", "PList", 
    "KinoSearch::Util::Obj");

struct kino_PostingList {
    KINO_POSTINGLIST_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
};

/* Abstract Getters.
 */
struct kino_Posting*
kino_PList_get_posting(kino_PostingList *self);
KINO_METHOD("Kino_PList_Get_Posting");

chy_u32_t
kino_PList_get_doc_freq(kino_PostingList *self);
KINO_METHOD("Kino_PList_Get_Doc_Freq");

/* Abstract convenience getter which returns the doc num of the current
 * posting.  Initially invalid.
 */
chy_u32_t
kino_PList_get_doc_num(kino_PostingList *self);
KINO_METHOD("Kino_PList_Get_Doc_Num");

/* Abstract method.
 *
 * Locate the PostingList object at a particular term.  [target] may be NULL,
 * in which case the iterator will be empty.
 */
void
kino_PList_seek(kino_PostingList *self, struct kino_Term *target);
KINO_METHOD("Kino_PList_Seek");

/* Abstract method.
 *
 * Occasionally optimized version of PList_Seek, designed to speed
 * sequential access.
 */
void
kino_PList_seek_lex(kino_PostingList *self, struct kino_Lexicon *lexicon);
KINO_METHOD("Kino_PList_Seek_Lex");

/* Abstract method.
 *
 * Advance the PostingList object to the next document.  Return false when the
 * iterator is exhausted, true otherwise.
 */
chy_bool_t
kino_PList_next(kino_PostingList *self);
KINO_METHOD("Kino_PList_Next");

/* Skip to the first doc number greater than or equal to [target].
 */
chy_bool_t
kino_PList_skip_to(kino_PostingList *self, chy_u32_t target);
KINO_METHOD("Kino_PList_Skip_To");

/* Abstract convienience method which invokes Post_Make_Scorer for this 
 * PostingList's posting.
 */
struct kino_Scorer*
kino_PList_make_scorer(kino_PostingList *self, struct kino_Similarity *sim,
                       void *weight, float weight_val);
KINO_METHOD("Kino_PList_Make_Scorer");

KINO_END_CLASS

#endif /* H_KINO_POSTINGLIST */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

