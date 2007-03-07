#ifndef H_KINO_TERMDOCS
#define H_KINO_TERMDOCS 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_TermDocs kino_TermDocs;
typedef struct KINO_TERMDOCS_VTABLE KINO_TERMDOCS_VTABLE;

struct kino_ByteBuf;
struct kino_Term;
struct kino_TermList;

#define KINO_TERM_DOCS_SENTINEL KINO_U32_MAX

KINO_CLASS("KinoSearch::Index::TermDocs", "TermDocs", 
    "KinoSearch::Util::Obj");

struct kino_TermDocs {
    KINO_TERMDOCS_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
};

/* Setters and getters....
 */
KINO_METHOD("Kino_TermDocs_Set_Doc_Freq",
void
kino_TermDocs_set_doc_freq(kino_TermDocs *self, kino_u32_t doc_freq));

KINO_METHOD("Kino_TermDocs_Get_Doc_Freq",
kino_u32_t
kino_TermDocs_get_doc_freq(kino_TermDocs *self));

KINO_METHOD("Kino_TermDocs_Get_Doc",
kino_u32_t
kino_TermDocs_get_doc(kino_TermDocs *self));

KINO_METHOD("Kino_TermDocs_Get_Freq",
kino_u32_t
kino_TermDocs_get_freq(kino_TermDocs *self));

KINO_METHOD("Kino_TermDocs_Get_Field_Boost_Byte",
kino_u8_t
kino_TermDocs_get_field_boost_byte(kino_TermDocs *self));

KINO_METHOD("Kino_TermDocs_Get_Positions",
struct kino_ByteBuf*
kino_TermDocs_get_positions(kino_TermDocs *self));

KINO_METHOD("Kino_TermDocs_Get_Boosts",
struct kino_ByteBuf*
kino_TermDocs_get_boosts(kino_TermDocs *self));

/* Locate the TermDocs object at a particular term.  [target] may be NULL, in
 * which case the iterator will be empty.
 */
KINO_METHOD("Kino_TermDocs_Seek",
void
kino_TermDocs_seek(kino_TermDocs *self, struct kino_Term *target));

/* Occasionally optimized version of TermDocs_Seek.
 */
KINO_METHOD("Kino_TermDocs_Seek_TL",
void
kino_TermDocs_seek_tl(kino_TermDocs *self, struct kino_TermList *term_list));

/* Advance the TermDocs object to the next document.  Return false when the
 * iterator is exhausted, true otherwise.
 */
KINO_METHOD("Kino_TermDocs_Next",
kino_bool_t
kino_TermDocs_next(kino_TermDocs *self));

/* Skip to the first doc number greater than or equal to [target].
 */
KINO_METHOD("Kino_TermDocs_Skip_To",
kino_bool_t
kino_TermDocs_skip_to(kino_TermDocs *self, kino_u32_t target));

/* Read up to [num_wanted] entries in one go.
 */
KINO_METHOD("Kino_TermDocs_Bulk_Read",
kino_u32_t
kino_TermDocs_bulk_read(kino_TermDocs *self, 
                        struct kino_ByteBuf *doc_nums_bb, 
                        struct kino_ByteBuf *field_boosts_bb, 
                        struct kino_ByteBuf *freqs_bb, 
                        struct kino_ByteBuf *prox_bb, 
                        struct kino_ByteBuf *boosts_bb, 
                        kino_u32_t num_wanted));

KINO_END_CLASS

#endif /* H_KINO_TERMDOCS */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

