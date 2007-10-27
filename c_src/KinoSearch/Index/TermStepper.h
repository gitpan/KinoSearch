#ifndef H_KINO_TERMSTEPPER
#define H_KINO_TERMSTEPPER 1

#include "KinoSearch/Util/Stepper.r"

typedef struct kino_TermStepper kino_TermStepper;
typedef struct KINO_TERMSTEPPER_VTABLE KINO_TERMSTEPPER_VTABLE;

struct kino_ByteBuf;
struct kino_InStream;
struct kino_Term;
struct kino_TermInfo;

KINO_FINAL_CLASS("KinoSearch::Index::TermStepper", "TermStepper", 
    "KinoSearch::Util::Stepper");

struct kino_TermStepper {
    KINO_TERMSTEPPER_VTABLE *_;
    KINO_STEPPER_MEMBER_VARS;

    struct kino_Term             *term;
    struct kino_TermInfo         *tinfo;
    struct kino_ByteBuf          *field;
    chy_i32_t                     skip_interval;
    chy_bool_t                    is_index;
};

/* Constructor.
 */
kino_TermStepper*
kino_TermStepper_new(const struct kino_ByteBuf *field,
                     chy_u32_t skip_interval, chy_bool_t is_index);

void
kino_TermStepper_destroy(kino_TermStepper *self);
KINO_METHOD("Kino_TermStepper_Destroy");

struct kino_ByteBuf*
kino_TermStepper_to_string(kino_TermStepper *self);
KINO_METHOD("Kino_TermStepper_To_String");

void
kino_TermStepper_read_record(kino_TermStepper *self, 
                             struct kino_InStream *instream);
KINO_METHOD("Kino_TermStepper_Read_Record");

void 
kino_TermStepper_write_record(kino_TermStepper* self, 
                              struct kino_OutStream *outstream, 
                              const char *term_text, 
                              size_t term_text_len,
                              const char *last_text, 
                              size_t last_text_len,
                              struct kino_TermInfo* tinfo, 
                              struct kino_TermInfo *last_tinfo,
                              chy_u64_t lex_filepos, 
                              chy_u64_t last_lex_filepos); 
KINO_METHOD("Kino_TermStepper_Write_Record");

/* Initialize.
 */
void
kino_TermStepper_reset(kino_TermStepper* self);
KINO_METHOD("Kino_TermStepper_Reset");

/* Setters...
 */
void
kino_TermStepper_set_tinfo(kino_TermStepper *self, 
                           const struct kino_TermInfo *tinfo);
KINO_METHOD("Kino_TermStepper_Set_TInfo");

void
kino_TermStepper_set_term(kino_TermStepper *self, 
                          const struct kino_Term *term);
KINO_METHOD("Kino_TermStepper_Set_Term");

void
kino_TermStepper_copy(kino_TermStepper *self, kino_TermStepper *other);
KINO_METHOD("Kino_TermStepper_Copy");

KINO_END_CLASS

#endif /* H_KINO_TERMSTEPPER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

