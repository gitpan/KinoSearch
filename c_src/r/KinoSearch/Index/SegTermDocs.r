/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_SEGTERMDOCS
#define R_KINO_SEGTERMDOCS 1

#include "KinoSearch/Index/SegTermDocs.h"

typedef void
(*kino_SegTermDocs_destroy_t)(kino_SegTermDocs *self);

typedef void
(*kino_SegTermDocs_set_doc_freq_t)(kino_SegTermDocs *self, kino_u32_t doc_freq);

typedef kino_u32_t
(*kino_SegTermDocs_get_doc_freq_t)(kino_SegTermDocs *self);

typedef kino_u32_t
(*kino_SegTermDocs_get_doc_t)(kino_SegTermDocs *self);

typedef kino_u32_t
(*kino_SegTermDocs_get_freq_t)(kino_SegTermDocs *self);

typedef kino_u8_t
(*kino_SegTermDocs_get_field_boost_byte_t)(kino_SegTermDocs *self);

typedef struct kino_ByteBuf*
(*kino_SegTermDocs_get_positions_t)(kino_SegTermDocs *self);

typedef struct kino_ByteBuf*
(*kino_SegTermDocs_get_boosts_t)(kino_SegTermDocs *self);

typedef void
(*kino_SegTermDocs_seek_t)(kino_SegTermDocs *self, struct kino_Term *target);

typedef void
(*kino_SegTermDocs_seek_tl_t)(kino_SegTermDocs *self, 
                         struct kino_TermList *term_list);

typedef kino_bool_t
(*kino_SegTermDocs_next_t)(kino_SegTermDocs *self);

typedef kino_bool_t
(*kino_SegTermDocs_skip_to_t)(kino_SegTermDocs *self, kino_u32_t target);

typedef kino_u32_t
(*kino_SegTermDocs_bulk_read_t)(kino_SegTermDocs *self, 
                           struct kino_ByteBuf *doc_nums_bb, 
                           struct kino_ByteBuf *field_boosts_bb, 
                           struct kino_ByteBuf *freqs_bb, 
                           struct kino_ByteBuf *prox_bb, 
                           struct kino_ByteBuf *boosts_bb, 
                           kino_u32_t num_wanted);

#define Kino_SegTermDocs_Clone(_self) \
    (_self)->_->clone((kino_Obj*)_self)

#define Kino_SegTermDocs_Destroy(_self) \
    (_self)->_->destroy((kino_Obj*)_self)

#define Kino_SegTermDocs_Equals(_self, _arg1) \
    (_self)->_->equals((kino_Obj*)_self, _arg1)

#define Kino_SegTermDocs_Hash_Code(_self) \
    (_self)->_->hash_code((kino_Obj*)_self)

#define Kino_SegTermDocs_Is_A(_self, _arg1) \
    (_self)->_->is_a((kino_Obj*)_self, _arg1)

#define Kino_SegTermDocs_To_String(_self) \
    (_self)->_->to_string((kino_Obj*)_self)

#define Kino_SegTermDocs_Serialize(_self, _arg1) \
    (_self)->_->serialize((kino_Obj*)_self, _arg1)

#define Kino_SegTermDocs_Set_Doc_Freq(_self, _arg1) \
    (_self)->_->set_doc_freq((kino_TermDocs*)_self, _arg1)

#define Kino_SegTermDocs_Get_Doc_Freq(_self) \
    (_self)->_->get_doc_freq((kino_TermDocs*)_self)

#define Kino_SegTermDocs_Get_Doc(_self) \
    (_self)->_->get_doc((kino_TermDocs*)_self)

#define Kino_SegTermDocs_Get_Freq(_self) \
    (_self)->_->get_freq((kino_TermDocs*)_self)

#define Kino_SegTermDocs_Get_Field_Boost_Byte(_self) \
    (_self)->_->get_field_boost_byte((kino_TermDocs*)_self)

#define Kino_SegTermDocs_Get_Positions(_self) \
    (_self)->_->get_positions((kino_TermDocs*)_self)

#define Kino_SegTermDocs_Get_Boosts(_self) \
    (_self)->_->get_boosts((kino_TermDocs*)_self)

#define Kino_SegTermDocs_Seek(_self, _arg1) \
    (_self)->_->seek((kino_TermDocs*)_self, _arg1)

#define Kino_SegTermDocs_Seek_TL(_self, _arg1) \
    (_self)->_->seek_tl((kino_TermDocs*)_self, _arg1)

#define Kino_SegTermDocs_Next(_self) \
    (_self)->_->next((kino_TermDocs*)_self)

#define Kino_SegTermDocs_Skip_To(_self, _arg1) \
    (_self)->_->skip_to((kino_TermDocs*)_self, _arg1)

#define Kino_SegTermDocs_Bulk_Read(_self, _arg1, _arg2, _arg3, _arg4, _arg5, _arg6) \
    (_self)->_->bulk_read((kino_TermDocs*)_self, _arg1, _arg2, _arg3, _arg4, _arg5, _arg6)

struct KINO_SEGTERMDOCS_VTABLE {
    KINO_OBJ_VTABLE *_;
    kino_u32_t refcount;
    KINO_OBJ_VTABLE *parent;
    const char *class_name;
    kino_Obj_clone_t clone;
    kino_Obj_destroy_t destroy;
    kino_Obj_equals_t equals;
    kino_Obj_hash_code_t hash_code;
    kino_Obj_is_a_t is_a;
    kino_Obj_to_string_t to_string;
    kino_Obj_serialize_t serialize;
    kino_TermDocs_set_doc_freq_t set_doc_freq;
    kino_TermDocs_get_doc_freq_t get_doc_freq;
    kino_TermDocs_get_doc_t get_doc;
    kino_TermDocs_get_freq_t get_freq;
    kino_TermDocs_get_field_boost_byte_t get_field_boost_byte;
    kino_TermDocs_get_positions_t get_positions;
    kino_TermDocs_get_boosts_t get_boosts;
    kino_TermDocs_seek_t seek;
    kino_TermDocs_seek_tl_t seek_tl;
    kino_TermDocs_next_t next;
    kino_TermDocs_skip_to_t skip_to;
    kino_TermDocs_bulk_read_t bulk_read;
};

extern KINO_SEGTERMDOCS_VTABLE KINO_SEGTERMDOCS;

#ifdef KINO_USE_SHORT_NAMES
  #define SegTermDocs kino_SegTermDocs
  #define SEGTERMDOCS KINO_SEGTERMDOCS
  #define SegTermDocs_new kino_SegTermDocs_new
  #define SegTermDocs_destroy kino_SegTermDocs_destroy
  #define SegTermDocs_set_doc_freq kino_SegTermDocs_set_doc_freq
  #define SegTermDocs_get_doc_freq kino_SegTermDocs_get_doc_freq
  #define SegTermDocs_get_doc kino_SegTermDocs_get_doc
  #define SegTermDocs_get_freq kino_SegTermDocs_get_freq
  #define SegTermDocs_get_field_boost_byte kino_SegTermDocs_get_field_boost_byte
  #define SegTermDocs_get_positions kino_SegTermDocs_get_positions
  #define SegTermDocs_get_boosts kino_SegTermDocs_get_boosts
  #define SegTermDocs_seek kino_SegTermDocs_seek
  #define SegTermDocs_seek_tl kino_SegTermDocs_seek_tl
  #define SegTermDocs_next kino_SegTermDocs_next
  #define SegTermDocs_skip_to kino_SegTermDocs_skip_to
  #define SegTermDocs_bulk_read kino_SegTermDocs_bulk_read
  #define SegTermDocs_Clone Kino_SegTermDocs_Clone
  #define SegTermDocs_Destroy Kino_SegTermDocs_Destroy
  #define SegTermDocs_Equals Kino_SegTermDocs_Equals
  #define SegTermDocs_Hash_Code Kino_SegTermDocs_Hash_Code
  #define SegTermDocs_Is_A Kino_SegTermDocs_Is_A
  #define SegTermDocs_To_String Kino_SegTermDocs_To_String
  #define SegTermDocs_Serialize Kino_SegTermDocs_Serialize
  #define SegTermDocs_Set_Doc_Freq Kino_SegTermDocs_Set_Doc_Freq
  #define SegTermDocs_Get_Doc_Freq Kino_SegTermDocs_Get_Doc_Freq
  #define SegTermDocs_Get_Doc Kino_SegTermDocs_Get_Doc
  #define SegTermDocs_Get_Freq Kino_SegTermDocs_Get_Freq
  #define SegTermDocs_Get_Field_Boost_Byte Kino_SegTermDocs_Get_Field_Boost_Byte
  #define SegTermDocs_Get_Positions Kino_SegTermDocs_Get_Positions
  #define SegTermDocs_Get_Boosts Kino_SegTermDocs_Get_Boosts
  #define SegTermDocs_Seek Kino_SegTermDocs_Seek
  #define SegTermDocs_Seek_TL Kino_SegTermDocs_Seek_TL
  #define SegTermDocs_Next Kino_SegTermDocs_Next
  #define SegTermDocs_Skip_To Kino_SegTermDocs_Skip_To
  #define SegTermDocs_Bulk_Read Kino_SegTermDocs_Bulk_Read
  #define SEGTERMDOCS KINO_SEGTERMDOCS
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_SEGTERMDOCS_MEMBER_VARS \
    kino_u32_t  refcount; \
    kino_u32_t  count; \
    kino_u32_t  doc_freq; \
    kino_u32_t  doc; \
    kino_u32_t  freq; \
    kino_u8_t  field_boost_byte; \
    kino_u32_t  skip_doc; \
    kino_u32_t  skip_count; \
    kino_u32_t  num_skips; \
    kino_i32_t  field_num; \
    struct kino_ByteBuf * positions; \
    struct kino_ByteBuf * boosts; \
    kino_u32_t  skip_interval; \
    struct kino_InStream * post_stream; \
    struct kino_InStream * skip_stream; \
    kino_bool_t  have_skipped; \
    kino_u64_t  post_fileptr; \
    kino_u64_t  skip_fileptr; \
    struct kino_Schema * schema; \
    struct kino_Folder * folder; \
    struct kino_SegInfo * seg_info; \
    struct kino_DelDocs * deldocs; \
    struct kino_FieldSpec * fspec; \
    struct kino_TermListReader * tl_reader


#ifdef KINO_WANT_SEGTERMDOCS_VTABLE
KINO_SEGTERMDOCS_VTABLE KINO_SEGTERMDOCS = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_TERMDOCS,
    "KinoSearch::Index::SegTermDocs",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_SegTermDocs_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_TermDocs_set_doc_freq_t)kino_SegTermDocs_set_doc_freq,
    (kino_TermDocs_get_doc_freq_t)kino_SegTermDocs_get_doc_freq,
    (kino_TermDocs_get_doc_t)kino_SegTermDocs_get_doc,
    (kino_TermDocs_get_freq_t)kino_SegTermDocs_get_freq,
    (kino_TermDocs_get_field_boost_byte_t)kino_SegTermDocs_get_field_boost_byte,
    (kino_TermDocs_get_positions_t)kino_SegTermDocs_get_positions,
    (kino_TermDocs_get_boosts_t)kino_SegTermDocs_get_boosts,
    (kino_TermDocs_seek_t)kino_SegTermDocs_seek,
    (kino_TermDocs_seek_tl_t)kino_SegTermDocs_seek_tl,
    (kino_TermDocs_next_t)kino_SegTermDocs_next,
    (kino_TermDocs_skip_to_t)kino_SegTermDocs_skip_to,
    (kino_TermDocs_bulk_read_t)kino_SegTermDocs_bulk_read
};
#endif /* KINO_WANT_SEGTERMDOCS_VTABLE */

#endif /* R_KINO_SEGTERMDOCS */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
