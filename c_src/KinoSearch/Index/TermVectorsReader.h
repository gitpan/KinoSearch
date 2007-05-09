#ifndef H_KINO_TERMVECTORSREADER
#define H_KINO_TERMVECTORSREADER 1

#include "KinoSearch/Util/Obj.r"

struct kino_ByteBuf;
struct kino_Schema;
struct kino_Folder;
struct kino_SegInfo;
struct kino_InStream;
struct kino_IntMap;

typedef struct kino_TermVectorsReader kino_TermVectorsReader;
typedef struct KINO_TERMVECTORSREADER_VTABLE KINO_TERMVECTORSREADER_VTABLE;

#define KINO_TVWRITER_FORMAT 1

KINO_FINAL_CLASS("KinoSearch::Index::TermVectorsReader", "TVReader", 
    "KinoSearch::Util::Obj");

struct kino_TermVectorsReader {
    KINO_TERMVECTORSREADER_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_Schema   *schema;
    struct kino_Folder   *folder;
    struct kino_SegInfo  *seg_info;
    struct kino_InStream *tv_in;
    struct kino_InStream *tvx_in;
};

/* Constructor.
 */
kino_TermVectorsReader*
kino_TVReader_new(struct kino_Schema *schema, struct kino_Folder *folder, 
                  struct kino_SegInfo *seg_info);

/* Return the raw bytes of an entry.
 */
void
kino_TVReader_read_record(kino_TermVectorsReader *self, 
                          chy_i32_t doc_num,
                          struct kino_ByteBuf *buffer);
KINO_METHOD("Kino_TVReader_Read_Record");

void
kino_TVReader_destroy(kino_TermVectorsReader *self);
KINO_METHOD("Kino_TVReader_Destroy");

KINO_END_CLASS

#endif /* H_KINO_TERMVECTORSREADER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

