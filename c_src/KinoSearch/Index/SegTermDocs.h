#ifndef H_KINO_SEGTERMDOCS
#define H_KINO_SEGTERMDOCS 1

#include "KinoSearch/Index/TermDocs.r"

typedef struct kino_SegTermDocs kino_SegTermDocs;
typedef struct KINO_SEGTERMDOCS_VTABLE KINO_SEGTERMDOCS_VTABLE;

struct kino_Schema;
struct kino_Folder;
struct kino_SegInfo;
struct kino_FieldSpec;
struct kino_InStream;
struct kino_DelDocs;
struct kino_ByteBuf;
struct kino_TermInfo;
struct kino_TermListReader;
struct kino_VArray;

KINO_CLASS("KinoSearch::Index::SegTermDocs", "SegTermDocs", 
    "KinoSearch::Index::TermDocs");

struct kino_SegTermDocs {
    KINO_SEGTERMDOCS_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    kino_u32_t             count;
    kino_u32_t             doc_freq;
    kino_u32_t             doc;
    kino_u32_t             freq;
    kino_u8_t              field_boost_byte;
    kino_u32_t             skip_doc;
    kino_u32_t             skip_count;
    kino_u32_t             num_skips;
    kino_i32_t             field_num;
    struct kino_ByteBuf   *positions;
    struct kino_ByteBuf   *boosts;
    kino_u32_t             skip_interval;
    struct kino_InStream  *post_stream;
    struct kino_InStream  *skip_stream;
    kino_bool_t            have_skipped;
    kino_u64_t             post_fileptr;
    kino_u64_t             skip_fileptr;
    struct kino_Schema    *schema;
    struct kino_Folder    *folder;
    struct kino_SegInfo   *seg_info;
    struct kino_DelDocs   *deldocs;
    struct kino_FieldSpec *fspec;
    struct kino_TermListReader *tl_reader;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_SegTermDocs*
kino_SegTermDocs_new(struct kino_Schema *schema, 
                     struct kino_Folder *folder, 
                     struct kino_SegInfo *seg_info, 
                     struct kino_TermListReader *tl_reader, 
                     struct kino_DelDocs *deldocs, 
                     kino_u32_t skip_interval));

KINO_METHOD("Kino_SegTermDocs_Destroy",
void 
kino_SegTermDocs_destroy(kino_SegTermDocs *self));

KINO_METHOD("Kino_SegTermDocs_Set_Doc_Freq",
void
kino_SegTermDocs_set_doc_freq(kino_SegTermDocs *self, kino_u32_t doc_freq));

KINO_METHOD("Kino_SegTermDocs_Get_Doc_Freq",
kino_u32_t
kino_SegTermDocs_get_doc_freq(kino_SegTermDocs *self));

KINO_METHOD("Kino_SegTermDocs_Get_Doc",
kino_u32_t
kino_SegTermDocs_get_doc(kino_SegTermDocs *self));

KINO_METHOD("Kino_SegTermDocs_Get_Freq",
kino_u32_t
kino_SegTermDocs_get_freq(kino_SegTermDocs *self));

KINO_METHOD("Kino_SegTermDocs_Get_Field_Boost_Byte",
kino_u8_t 
kino_SegTermDocs_get_field_boost_byte(kino_SegTermDocs *self));

KINO_METHOD("Kino_SegTermDocs_Get_Positions",
struct kino_ByteBuf*
kino_SegTermDocs_get_positions(kino_SegTermDocs *self));

KINO_METHOD("Kino_SegTermDocs_Get_Boosts",
struct kino_ByteBuf*
kino_SegTermDocs_get_boosts(kino_SegTermDocs *self));

KINO_METHOD("Kino_SegTermDocs_Bulk_Read",
kino_u32_t 
kino_SegTermDocs_bulk_read(kino_SegTermDocs *self, 
                           struct kino_ByteBuf *doc_nums_bb, 
                           struct kino_ByteBuf *field_boosts_bb, 
                           struct kino_ByteBuf *freqs_bb, 
                           struct kino_ByteBuf *prox_bb, 
                           struct kino_ByteBuf *boosts_bb, 
                           kino_u32_t num_wanted));

KINO_METHOD("Kino_SegTermDocs_Next",
kino_bool_t
kino_SegTermDocs_next(kino_SegTermDocs *self));

KINO_METHOD("Kino_SegTermDocs_Skip_To",
kino_bool_t
kino_SegTermDocs_skip_to(kino_SegTermDocs *self, kino_u32_t target));

KINO_METHOD("Kino_SegTermDocs_Seek",
void
kino_SegTermDocs_seek(kino_SegTermDocs *self, struct kino_Term *target));

KINO_METHOD("Kino_SegTermDocs_Seek_TL",
void
kino_SegTermDocs_seek_tl(kino_SegTermDocs *self, 
                         struct kino_TermList *term_list));

KINO_END_CLASS

#endif /* H_KINO_SEGTERMDOCS */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

