#ifndef H_KINO_DELDOCS
#define H_KINO_DELDOCS 1

#include "KinoSearch/Util/BitVector.r"

struct kino_ByteBuf;
struct kino_TermDocs;
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
    kino_i32_t            del_gen;
    struct kino_InvIndex *invindex;
    struct kino_SegInfo  *seg_info;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_DelDocs*
kino_DelDocs_new(struct kino_InvIndex *invindex, 
                 struct kino_SegInfo *seg_info));

/* Read a segment's current deletions file.
 */
KINO_METHOD("Kino_DelDocs_Read_Deldocs",
void
kino_DelDocs_read_deldocs(kino_DelDocs *self));

/* Write the deleted documents out to a .del file.
 */
KINO_METHOD("Kino_DelDocs_Write_Deldocs",
void
kino_DelDocs_write_deldocs(kino_DelDocs *self));

/* Produce an array of kino_i32_t which wraps around deleted documents.  The
 * position in the array represents the original doc number, and the value
 * represents the new number.  Deleted docs are assigned -1.  So if you had 4
 * docs and doc 2 was deleted, the array would have the values...
 * { 0, 1, -1, 2 }.
 * 
 * [offset] is added to each valid document number, so with an offset of 1000,
 * the array in the previous example would be { 1000, -1, 1001, 1002 }.
 */
KINO_METHOD("Kino_DelDocs_Generate_Doc_Map",
struct kino_IntMap*
kino_DelDocs_generate_doc_map(kino_DelDocs *self, kino_i32_t offset)); 

/* Iterate over a TermDocs, deleting any document that wasn't already deleted.
 */
KINO_METHOD("Kino_DelDocs_Delete_By_Term_Docs",
void  
kino_DelDocs_delete_by_term_docs(kino_DelDocs *self, 
                                 struct kino_TermDocs *term_docs));

KINO_METHOD("Kino_DelDocs_Destroy",
void
kino_DelDocs_destroy(kino_DelDocs *self));

KINO_END_CLASS

#endif /* H_KINO_DELDOCS */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

