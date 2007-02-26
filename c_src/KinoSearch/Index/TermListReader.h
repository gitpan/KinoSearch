#ifndef H_KINO_TERMLISTREADER
#define H_KINO_TERMLISTREADER 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_TermListReader kino_TermListReader;
typedef struct KINO_TERMLISTREADER_VTABLE KINO_TERMLISTREADER_VTABLE;

struct kino_Schema;
struct kino_Folder;
struct kino_SegInfo;
struct kino_Term;
struct kino_TermInfo;

KINO_CLASS("KinoSearch::Index::TermListReader", "TLReader", 
    "KinoSearch::Util::Obj");

struct kino_TermListReader {
    KINO_TERMLISTREADER_VTABLE *_;
    kino_u32_t refcount;
    struct kino_Schema *schema;
    struct kino_Folder *folder;
    struct kino_SegInfo *seg_info;
    struct kino_SegTermList **term_lists;
    kino_u32_t num_fields;
    kino_i32_t index_interval;
    kino_i32_t skip_interval;
};

KINO_FUNCTION(
kino_TermListReader*
kino_TLReader_new(struct kino_Schema *schema, struct kino_Folder *folder,
                  struct kino_SegInfo *seg_info));

KINO_METHOD("Kino_TLReader_Destroy",
void
kino_TLReader_destroy(kino_TermListReader *self));

/* Return a SegTermList pre-seeked to the supplied Term.  
 *
 * Will return NULL if...
 *
 *     o the field is not indexed  
 *     o the field is not represented in this segment
 *     o the target term is NULL
 */
KINO_METHOD("Kino_TLReader_Field_Terms",
struct kino_SegTermList*
kino_TLReader_field_terms(kino_TermListReader *self, 
                          struct kino_Term *target));

KINO_METHOD("Kino_TLReader_Start_Field_Terms",
struct kino_SegTermList*
kino_TLReader_start_field_terms(kino_TermListReader *self, 
                                struct kino_ByteBuf *field_name));

/* If the term can be found, return a term info, otherwise return NULL.
 */
KINO_METHOD("Kino_TLReader_Fetch_Term_Info",
struct kino_TermInfo*
kino_TLReader_fetch_term_info(kino_TermListReader *self, 
                              struct kino_Term *term));

KINO_METHOD("Kino_TLReader_Get_Skip_Interval",
kino_u32_t
kino_TLReader_get_skip_interval(kino_TermListReader *self));

KINO_METHOD("Kino_TLReader_Close",
void
kino_TLReader_close(kino_TermListReader *self));

KINO_END_CLASS

#endif /* H_KINO_TERMLISTREADER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

