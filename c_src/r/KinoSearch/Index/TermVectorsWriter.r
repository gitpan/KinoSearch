/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/

#ifndef R_KINO_TVWRITER
#define R_KINO_TVWRITER 1

#include "KinoSearch/Index/TermVectorsWriter.h"

typedef void
(*kino_TVWriter_destroy_t)(kino_TermVectorsWriter *self);

typedef void
(*kino_TVWriter_add_segment_t)(kino_TermVectorsWriter *self, 
                          struct kino_TermVectorsReader *tv_reader,
                          struct kino_IntMap *doc_map,
                          kino_u32_t max_doc);

typedef void
(*kino_TVWriter_finish_t)(kino_TermVectorsWriter *self);

typedef struct kino_ByteBuf*
(*kino_TVWriter_tv_string_t)(kino_TermVectorsWriter *self, 
                        struct kino_TokenBatch *batch);

#define Kino_TVWriter_Clone(_self) \
    kino_Obj_clone((kino_Obj*)_self)

#define Kino_TVWriter_Destroy(_self) \
    kino_TVWriter_destroy((kino_TermVectorsWriter*)_self)

#define Kino_TVWriter_Equals(_self, _arg1) \
    kino_Obj_equals((kino_Obj*)_self, _arg1)

#define Kino_TVWriter_Hash_Code(_self) \
    kino_Obj_hash_code((kino_Obj*)_self)

#define Kino_TVWriter_Is_A(_self, _arg1) \
    kino_Obj_is_a((kino_Obj*)_self, _arg1)

#define Kino_TVWriter_To_String(_self) \
    kino_Obj_to_string((kino_Obj*)_self)

#define Kino_TVWriter_Serialize(_self, _arg1) \
    kino_Obj_serialize((kino_Obj*)_self, _arg1)

#define Kino_TVWriter_Add_Segment(_self, _arg1, _arg2, _arg3) \
    kino_TVWriter_add_segment((kino_TermVectorsWriter*)_self, _arg1, _arg2, _arg3)

#define Kino_TVWriter_Finish(_self) \
    kino_TVWriter_finish((kino_TermVectorsWriter*)_self)

#define Kino_TVWriter_TV_String(_self, _arg1) \
    kino_TVWriter_tv_string((kino_TermVectorsWriter*)_self, _arg1)

struct KINO_TERMVECTORSWRITER_VTABLE {
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
    kino_TVWriter_add_segment_t add_segment;
    kino_TVWriter_finish_t finish;
    kino_TVWriter_tv_string_t tv_string;
};

extern KINO_TERMVECTORSWRITER_VTABLE KINO_TERMVECTORSWRITER;

#ifdef KINO_USE_SHORT_NAMES
  #define TermVectorsWriter kino_TermVectorsWriter
  #define TERMVECTORSWRITER KINO_TERMVECTORSWRITER
  #define TVWriter_new kino_TVWriter_new
  #define TVWriter_destroy_t kino_TVWriter_destroy_t
  #define TVWriter_destroy kino_TVWriter_destroy
  #define TVWriter_add_segment_t kino_TVWriter_add_segment_t
  #define TVWriter_add_segment kino_TVWriter_add_segment
  #define TVWriter_finish_t kino_TVWriter_finish_t
  #define TVWriter_finish kino_TVWriter_finish
  #define TVWriter_tv_string_t kino_TVWriter_tv_string_t
  #define TVWriter_tv_string kino_TVWriter_tv_string
  #define TVWriter_Clone Kino_TVWriter_Clone
  #define TVWriter_Destroy Kino_TVWriter_Destroy
  #define TVWriter_Equals Kino_TVWriter_Equals
  #define TVWriter_Hash_Code Kino_TVWriter_Hash_Code
  #define TVWriter_Is_A Kino_TVWriter_Is_A
  #define TVWriter_To_String Kino_TVWriter_To_String
  #define TVWriter_Serialize Kino_TVWriter_Serialize
  #define TVWriter_Add_Segment Kino_TVWriter_Add_Segment
  #define TVWriter_Finish Kino_TVWriter_Finish
  #define TVWriter_TV_String Kino_TVWriter_TV_String
  #define TERMVECTORSWRITER KINO_TERMVECTORSWRITER
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_TERMVECTORSWRITER_MEMBER_VARS \
    kino_u32_t  refcount; \
    struct kino_InvIndex * invindex; \
    struct kino_SegInfo * seg_info; \
    struct kino_OutStream * tv_out; \
    struct kino_OutStream * tvx_out


#ifdef KINO_WANT_TERMVECTORSWRITER_VTABLE
KINO_TERMVECTORSWRITER_VTABLE KINO_TERMVECTORSWRITER = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_OBJ,
    "KinoSearch::Index::TermVectorsWriter",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_TVWriter_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_TVWriter_add_segment_t)kino_TVWriter_add_segment,
    (kino_TVWriter_finish_t)kino_TVWriter_finish,
    (kino_TVWriter_tv_string_t)kino_TVWriter_tv_string
};
#endif /* KINO_WANT_TERMVECTORSWRITER_VTABLE */

#endif /* R_KINO_TVWRITER */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
