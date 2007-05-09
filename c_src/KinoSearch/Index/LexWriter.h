#ifndef H_KINO_LEXWRITER
#define H_KINO_LEXWRITER 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_LexWriter kino_LexWriter;
typedef struct KINO_LEXWRITER_VTABLE KINO_LEXWRITER_VTABLE;

struct kino_ByteBuf;
struct kino_Hash;
struct kino_InvIndex;
struct kino_OutStream;
struct kino_TermInfo;
struct kino_SegInfo;

KINO_FINAL_CLASS("KinoSearch::Index::LexWriter", "LexWriter", 
    "KinoSearch::Util::Obj");

struct kino_LexWriter {
    KINO_LEXWRITER_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_InvIndex    *invindex;
    struct kino_SegInfo     *seg_info;
    struct kino_TermStepper *stepper;
    struct kino_OutStream   *outstream;
    struct kino_ByteBuf     *filename;
    struct kino_Hash        *counts;
    chy_bool_t               is_index;
    chy_bool_t               temp_mode;
    chy_i32_t                index_interval;
    chy_i32_t                skip_interval;
    kino_LexWriter          *other;
    struct kino_ByteBuf     *last_text;
    struct kino_TermInfo    *last_tinfo;
    chy_u64_t                last_lex_filepos;
    chy_i32_t                count;
};

/* Constructor. 
 */
kino_LexWriter*
kino_LexWriter_new(struct kino_InvIndex *invindex, 
                   struct kino_SegInfo *seg_info,
                   chy_i32_t is_index);

/* Prepare to write the .lex and .lexx files for a field.
 */
void
kino_LexWriter_start_field(kino_LexWriter *self, chy_i32_t field_num);
KINO_METHOD("Kino_LexWriter_Start_Field");

/* Finish writing the current field.  Close files, generate metadata.
 */
void
kino_LexWriter_finish_field(kino_LexWriter *self, chy_i32_t field_num);
KINO_METHOD("Kino_LexWriter_Finish_Field");

/* Prepare to write terms to a temporary file.
 */
void
kino_LexWriter_enter_temp_mode(kino_LexWriter *self, 
                               struct kino_OutStream *temp_outstream);
KINO_METHOD("Kino_LexWriter_Enter_Temp_Mode");

/* Stop writing terms to temp file.  Abandon (but don't close) the file.
 */
void
kino_LexWriter_leave_temp_mode(kino_LexWriter *self);
KINO_METHOD("Kino_LexWriter_Leave_Temp_Mode");

/* Add a Term's text and its associated TermInfo (which has the Term's 
 * field number).
 */
void 
kino_LexWriter_add(kino_LexWriter* self, struct kino_ByteBuf* term_text,
                   struct kino_TermInfo* tinfo);
KINO_METHOD("Kino_LexWriter_Add");

/* Conclude business.
 */
void
kino_LexWriter_finish(kino_LexWriter *self);
KINO_METHOD("Kino_LexWriter_Finish");

void
kino_LexWriter_destroy(kino_LexWriter *self);
KINO_METHOD("Kino_LexWriter_Destroy");

KINO_END_CLASS

#endif /* H_KINO_LEXWRITER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

