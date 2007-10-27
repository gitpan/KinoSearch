#ifndef H_KINO_SKIPSTEPPER
#define H_KINO_SKIPSTEPPER 1

#include "KinoSearch/Util/Stepper.r"

typedef struct kino_SkipStepper kino_SkipStepper;
typedef struct KINO_SKIPSTEPPER_VTABLE KINO_SKIPSTEPPER_VTABLE;

struct kino_InStream;
struct kino_OutStream;

KINO_FINAL_CLASS("KinoSearch::Index::SkipStepper", "SkipStepper", 
    "KinoSearch::Util::Stepper");

struct kino_SkipStepper {
    KINO_SKIPSTEPPER_VTABLE *_;
    KINO_STEPPER_MEMBER_VARS;
    chy_u32_t          doc_num;
    chy_u64_t          filepos;
};

/* Constructor.
 */
kino_SkipStepper*
kino_SkipStepper_new();

struct kino_ByteBuf*
kino_SkipStepper_to_string(kino_SkipStepper *self);
KINO_METHOD("Kino_SkipStepper_To_String");

void
kino_SkipStepper_read_record(kino_SkipStepper *self, 
                             struct kino_InStream *instream);
KINO_METHOD("Kino_SkipStepper_Read_Record");

void
kino_SkipStepper_write_record(kino_SkipStepper *self, 
                              struct kino_OutStream *outstream, 
                              chy_u32_t last_doc_num,
                              chy_u64_t last_filepos);
KINO_METHOD("Kino_SkipStepper_Write_Record");


/* Set a base document number and a base file position which Read_Record will
 * add onto with its deltas.
 */
void
kino_SkipStepper_reset(kino_SkipStepper *self, chy_u32_t doc_num, 
                       chy_u64_t filepos);
KINO_METHOD("Kino_SkipStepper_Reset");

KINO_END_CLASS

#endif /* H_KINO_SKIPSTEPPER */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

