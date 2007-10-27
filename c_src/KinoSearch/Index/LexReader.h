#ifndef H_KINO_LEXREADER
#define H_KINO_LEXREADER 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_LexReader kino_LexReader;
typedef struct KINO_LEXREADER_VTABLE KINO_LEXREADER_VTABLE;

struct kino_Schema;
struct kino_Folder;
struct kino_SegInfo;
struct kino_Term;
struct kino_TermInfo;

KINO_CLASS("KinoSearch::Index::LexReader", "LexReader", 
    "KinoSearch::Util::Obj");

struct kino_LexReader {
    KINO_LEXREADER_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_Schema *schema;
    struct kino_Folder *folder;
    struct kino_SegInfo *seg_info;
    struct kino_SegLexicon **lexicons;
    chy_u32_t num_fields;
    chy_i32_t index_interval;
    chy_i32_t skip_interval;
};

kino_LexReader*
kino_LexReader_new(struct kino_Schema *schema, struct kino_Folder *folder,
                   struct kino_SegInfo *seg_info);

void
kino_LexReader_destroy(kino_LexReader *self);
KINO_METHOD("Kino_LexReader_Destroy");

/* Return a SegLexicon pre-seeked to the supplied Term.  
 *
 * Will return NULL if...
 *
 *     o the field is not indexed  
 *     o the field is not represented in this segment
 *     o the target term is NULL
 */
struct kino_SegLexicon*
kino_LexReader_look_up_term(kino_LexReader *self, 
                            struct kino_Term *target);
KINO_METHOD("Kino_LexReader_Look_Up_Term");

struct kino_SegLexicon*
kino_LexReader_look_up_field(kino_LexReader *self, 
                             struct kino_ByteBuf *field_name);
KINO_METHOD("Kino_LexReader_Look_Up_Field");

/* If the term can be found, return a term info, otherwise return NULL.
 */
struct kino_TermInfo*
kino_LexReader_fetch_term_info(kino_LexReader *self, 
                               struct kino_Term *term);
KINO_METHOD("Kino_LexReader_Fetch_Term_Info");

chy_u32_t
kino_LexReader_get_skip_interval(kino_LexReader *self);
KINO_METHOD("Kino_LexReader_Get_Skip_Interval");

void
kino_LexReader_close(kino_LexReader *self);
KINO_METHOD("Kino_LexReader_Close");

KINO_END_CLASS

#endif /* H_KINO_LEXREADER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

