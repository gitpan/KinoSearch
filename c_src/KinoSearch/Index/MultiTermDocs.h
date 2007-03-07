#ifndef H_KINO_MULTITERMDOCS
#define H_KINO_MULTITERMDOCS 1

#include "KinoSearch/Index/TermDocs.r"

typedef struct kino_MultiTermDocs kino_MultiTermDocs;
typedef struct KINO_MULTITERMDOCS_VTABLE KINO_MULTITERMDOCS_VTABLE;

KINO_CLASS("KinoSearch::Index::MultiTermDocs", "MultiTermDocs", 
    "KinoSearch::Index::TermDocs");

struct kino_MultiTermDocs {
    KINO_MULTITERMDOCS_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    kino_u32_t      num_subs;
    kino_u32_t      base;
    kino_u32_t      pointer;
    kino_u32_t     *starts;
    kino_TermDocs **sub_term_docs;
    kino_TermDocs  *current;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_MultiTermDocs*
kino_MultiTermDocs_new(kino_u32_t num_subs, kino_TermDocs **sub_term_docs, 
                       kino_u32_t *starts));

KINO_METHOD("Kino_MultiTermDocs_Destroy",
void 
kino_MultiTermDocs_destroy(kino_MultiTermDocs *self));

/* Throws an error, as this is illegal on a MultiTermDocs.
 */
KINO_METHOD("Kino_MultiTermDocs_Set_Doc_Freq",
void
kino_MultiTermDocs_set_doc_freq(kino_MultiTermDocs *self, kino_u32_t doc_freq));

KINO_METHOD("Kino_MultiTermDocs_Get_Doc_Freq",
kino_u32_t
kino_MultiTermDocs_get_doc_freq(kino_MultiTermDocs *self));

KINO_METHOD("Kino_MultiTermDocs_Get_Doc",
kino_u32_t
kino_MultiTermDocs_get_doc(kino_MultiTermDocs *self));

KINO_METHOD("Kino_MultiTermDocs_Get_Freq",
kino_u32_t
kino_MultiTermDocs_get_freq(kino_MultiTermDocs *self));

KINO_METHOD("Kino_MultiTermDocs_Get_Field_Boost_Byte",
kino_u8_t 
kino_MultiTermDocs_get_field_boost_byte(kino_MultiTermDocs *self));

KINO_METHOD("Kino_MultiTermDocs_Get_Positions",
struct kino_ByteBuf*
kino_MultiTermDocs_get_positions(kino_MultiTermDocs *self));

KINO_METHOD("Kino_MultiTermDocs_Get_Boosts",
struct kino_ByteBuf*
kino_MultiTermDocs_get_boosts(kino_MultiTermDocs *self));

KINO_METHOD("Kino_MultiTermDocs_Bulk_Read",
kino_u32_t 
kino_MultiTermDocs_bulk_read(kino_MultiTermDocs *self, 
                             struct kino_ByteBuf *doc_nums_bb, 
                             struct kino_ByteBuf *field_boosts_bb, 
                             struct kino_ByteBuf *freqs_bb, 
                             struct kino_ByteBuf *prox_bb, 
                             struct kino_ByteBuf *boosts_bb, 
                             kino_u32_t num_wanted));

KINO_METHOD("Kino_MultiTermDocs_Next",
kino_bool_t
kino_MultiTermDocs_next(kino_MultiTermDocs *self));

KINO_METHOD("Kino_MultiTermDocs_Seek",
void
kino_MultiTermDocs_seek(kino_MultiTermDocs *self, struct kino_Term *target));

KINO_METHOD("Kino_MultiTermDocs_Skip_To",
kino_bool_t
kino_MultiTermDocs_skip_to(kino_MultiTermDocs *self, kino_u32_t target));

KINO_END_CLASS

#endif /* H_KINO_MULTITERMDOCS */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

