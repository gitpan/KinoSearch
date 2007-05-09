/** @file */
/***********************************************

 !!!! DO NOT EDIT THIS FILE !!!!

 All content has been auto-generated by 
 the boilerplater.pl utility.

 See boilerplater's documentation for details.

 ***********************************************/



#ifndef R_KINO_MULTILEXICON
#define R_KINO_MULTILEXICON 1

#include "KinoSearch/Index/MultiLexicon.h"

#define KINO_MULTILEXICON_BOILERPLATE

typedef void
(*kino_MultiLex_destroy_t)(kino_MultiLexicon *self);

typedef void
(*kino_MultiLex_seek_t)(kino_MultiLexicon *self, struct kino_Term *term);

typedef chy_bool_t
(*kino_MultiLex_next_t)(kino_MultiLexicon *self);

typedef void
(*kino_MultiLex_reset_t)(kino_MultiLexicon *self);

typedef chy_i32_t
(*kino_MultiLex_get_term_num_t)(kino_MultiLexicon *self);

typedef struct kino_Term*
(*kino_MultiLex_get_term_t)(kino_MultiLexicon *self);

typedef struct kino_IntMap*
(*kino_MultiLex_build_sort_cache_t)(kino_MultiLexicon *self, 
                               struct kino_PostingList *plist, 
                               chy_u32_t max_doc);

#define Kino_MultiLex_Clone(self) \
    (self)->_->clone((kino_Obj*)self)

#define Kino_MultiLex_Destroy(self) \
    (self)->_->destroy((kino_Obj*)self)

#define Kino_MultiLex_Equals(self, other) \
    (self)->_->equals((kino_Obj*)self, other)

#define Kino_MultiLex_Hash_Code(self) \
    (self)->_->hash_code((kino_Obj*)self)

#define Kino_MultiLex_Is_A(self, target_vtable) \
    (self)->_->is_a((kino_Obj*)self, target_vtable)

#define Kino_MultiLex_To_String(self) \
    (self)->_->to_string((kino_Obj*)self)

#define Kino_MultiLex_Serialize(self, target) \
    (self)->_->serialize((kino_Obj*)self, target)

#define Kino_MultiLex_Seek(self, term) \
    (self)->_->seek((kino_Lexicon*)self, term)

#define Kino_MultiLex_Next(self) \
    (self)->_->next((kino_Lexicon*)self)

#define Kino_MultiLex_Reset(self) \
    (self)->_->reset((kino_Lexicon*)self)

#define Kino_MultiLex_Get_Term_Num(self) \
    (self)->_->get_term_num((kino_Lexicon*)self)

#define Kino_MultiLex_Get_Term(self) \
    (self)->_->get_term((kino_Lexicon*)self)

#define Kino_MultiLex_Build_Sort_Cache(self, plist, max_doc) \
    (self)->_->build_sort_cache((kino_Lexicon*)self, plist, max_doc)

struct KINO_MULTILEXICON_VTABLE {
    KINO_OBJ_VTABLE *_;
    chy_u32_t refcount;
    KINO_OBJ_VTABLE *parent;
    const char *class_name;
    kino_Obj_clone_t clone;
    kino_Obj_destroy_t destroy;
    kino_Obj_equals_t equals;
    kino_Obj_hash_code_t hash_code;
    kino_Obj_is_a_t is_a;
    kino_Obj_to_string_t to_string;
    kino_Obj_serialize_t serialize;
    kino_Lex_seek_t seek;
    kino_Lex_next_t next;
    kino_Lex_reset_t reset;
    kino_Lex_get_term_num_t get_term_num;
    kino_Lex_get_term_t get_term;
    kino_Lex_build_sort_cache_t build_sort_cache;
};

extern KINO_MULTILEXICON_VTABLE KINO_MULTILEXICON;

#ifdef KINO_USE_SHORT_NAMES
  #define MultiLexicon kino_MultiLexicon
  #define MULTILEXICON KINO_MULTILEXICON
  #define MultiLex_new kino_MultiLex_new
  #define MultiLex_destroy kino_MultiLex_destroy
  #define MultiLex_seek kino_MultiLex_seek
  #define MultiLex_next kino_MultiLex_next
  #define MultiLex_reset kino_MultiLex_reset
  #define MultiLex_get_term_num kino_MultiLex_get_term_num
  #define MultiLex_get_term kino_MultiLex_get_term
  #define MultiLex_build_sort_cache kino_MultiLex_build_sort_cache
  #define MultiLex_Clone Kino_MultiLex_Clone
  #define MultiLex_Destroy Kino_MultiLex_Destroy
  #define MultiLex_Equals Kino_MultiLex_Equals
  #define MultiLex_Hash_Code Kino_MultiLex_Hash_Code
  #define MultiLex_Is_A Kino_MultiLex_Is_A
  #define MultiLex_To_String Kino_MultiLex_To_String
  #define MultiLex_Serialize Kino_MultiLex_Serialize
  #define MultiLex_Seek Kino_MultiLex_Seek
  #define MultiLex_Next Kino_MultiLex_Next
  #define MultiLex_Reset Kino_MultiLex_Reset
  #define MultiLex_Get_Term_Num Kino_MultiLex_Get_Term_Num
  #define MultiLex_Get_Term Kino_MultiLex_Get_Term
  #define MultiLex_Build_Sort_Cache Kino_MultiLex_Build_Sort_Cache
#endif /* KINO_USE_SHORT_NAMES */

#define KINO_MULTILEXICON_MEMBER_VARS \
    chy_u32_t  refcount; \
    struct kino_ByteBuf * field; \
    struct kino_Term * term; \
    struct kino_PriorityQueue * lex_q; \
    struct kino_VArray * seg_lexicons; \
    struct kino_LexCache * lex_cache; \
    chy_i32_t  term_num

#ifdef KINO_WANT_MULTILEXICON_VTABLE
KINO_MULTILEXICON_VTABLE KINO_MULTILEXICON = {
    (KINO_OBJ_VTABLE*)&KINO_VIRTUALTABLE,
    1,
    (KINO_OBJ_VTABLE*)&KINO_LEXICON,
    "KinoSearch::Index::MultiLexicon",
    (kino_Obj_clone_t)kino_Obj_clone,
    (kino_Obj_destroy_t)kino_MultiLex_destroy,
    (kino_Obj_equals_t)kino_Obj_equals,
    (kino_Obj_hash_code_t)kino_Obj_hash_code,
    (kino_Obj_is_a_t)kino_Obj_is_a,
    (kino_Obj_to_string_t)kino_Obj_to_string,
    (kino_Obj_serialize_t)kino_Obj_serialize,
    (kino_Lex_seek_t)kino_MultiLex_seek,
    (kino_Lex_next_t)kino_MultiLex_next,
    (kino_Lex_reset_t)kino_MultiLex_reset,
    (kino_Lex_get_term_num_t)kino_MultiLex_get_term_num,
    (kino_Lex_get_term_t)kino_MultiLex_get_term,
    (kino_Lex_build_sort_cache_t)kino_MultiLex_build_sort_cache
};
#endif /* KINO_WANT_MULTILEXICON_VTABLE */

#undef KINO_MULTILEXICON_BOILERPLATE


#endif /* R_KINO_MULTILEXICON */


/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
