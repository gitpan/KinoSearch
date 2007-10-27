#ifndef H_KINO_DELDOCS
#define H_KINO_DELDOCS 1

#include "KinoSearch/Util/BitVector.r"

struct kino_ByteBuf;
struct kino_PostingList;
struct kino_InvIndex;
struct kino_SegInfo;
struct kino_IntMap;

typedef struct kino_DelDocs kino_DelDocs;
typedef struct KINO_DELDOCS_VTABLE KINO_DELDOCS_VTABLE;

KINO_FINAL_CLASS("KinoSearch::Index::DelDocs", "DelDocs",
    "KinoSearch::Util::BitVector");

struct kino_DelDocs {
    KINO_DELDOCS_VTABLE *_;
    KINO_BITVECTOR_MEMBER_VARS;
    chy_i32_t             del_gen;
    struct kino_InvIndex *invindex;
    struct kino_SegInfo  *seg_info;
};

/* Constructor.
 */
kino_DelDocs*
kino_DelDocs_new(struct kino_InvIndex *invindex, 
                 struct kino_SegInfo *seg_info);

/* Read a segment's current deletions file.
 */
void
kino_DelDocs_read_deldocs(kino_DelDocs *self);
KINO_METHOD("Kino_DelDocs_Read_Deldocs");

/* Write the deleted documents out to a .del file.
 */
void
kino_DelDocs_write_deldocs(kino_DelDocs *self);
KINO_METHOD("Kino_DelDocs_Write_Deldocs");

/* Produce an array of chy_i32_t which wraps around deleted documents.  The
 * position in the array represents the original doc number, and the value
 * represents the new number.  Deleted docs are assigned -1.  So if you had 4
 * docs and doc 2 was deleted, the array would have the values...
 * { 0, 1, -1, 2 }.
 * 
 * [offset] is added to each valid document number, so with an offset of 1000,
 * the array in the previous example would be { 1000, -1, 1001, 1002 }.
 */
struct kino_IntMap*
kino_DelDocs_generate_doc_map(kino_DelDocs *self, chy_i32_t offset);
KINO_METHOD("Kino_DelDocs_Generate_Doc_Map");

/* Delete all the documents represented by a PostingList.
 */
void  
kino_DelDocs_delete_postinglist(kino_DelDocs *self, 
                                 struct kino_PostingList *plist);
KINO_METHOD("Kino_DelDocs_Delete_PostingList");

void
kino_DelDocs_destroy(kino_DelDocs *self);
KINO_METHOD("Kino_DelDocs_Destroy");

KINO_END_CLASS

#endif /* H_KINO_DELDOCS */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

