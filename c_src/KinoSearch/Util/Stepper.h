/** 
 * @class KinoSearch::Util::Stepper Stepper.r
 * @brief Abstract encoder/decoder
 * 
 * Many KinoSearch files consist of a single variable length record type
 * repeated over and over.  A Stepper both reads and writes such a file.
 * 
 * Since the write algorithms for different Stepper types may require
 * differing argument lists, it is left to the subclass to define the routine.
 * 
 * However, since all Stepper subclasses must implement Stepper_Read_Record,
 * all of them may inherit the debugging aids Stepper_Dump and
 * Stepper_Dump_To_File.
 *
 * Sometimes it is possible to change a file's format by changing only a
 * Stepper.  In that case, a compatibility version of the old class may be
 * squirreled away as a plugin, to be accessed only when reading files written
 * to the old format.  This cuts down on special-case code in the most current
 * version.
 * 
 * Furthermore, isolating I/O code within a Stepper typically clarifies the
 * logic of the class which calls Stepper_Read_Record.
 */

#ifndef H_KINO_STEPPER
#define H_KINO_STEPPER 1

#include "KinoSearch/Util/Obj.r"

typedef struct kino_Stepper kino_Stepper;
typedef struct KINO_STEPPER_VTABLE KINO_STEPPER_VTABLE;

struct kino_InStream;
struct kino_OutStream;

KINO_CLASS("KinoSearch::Util::Stepper", "Stepper", "KinoSearch::Util::Obj");

struct kino_Stepper {
    KINO_STEPPER_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
};

/* Abstract method.  Read the next record from the instream, storing state in
 * [self].
 */
void
kino_Stepper_read_record(kino_Stepper *self, struct kino_InStream *instream);
KINO_METHOD("Kino_Stepper_Read_Record");

/* Step through the file, writing Stepper_To_String() to stdout for each
 * record until the stream's end is reached.
 */
void
kino_Stepper_dump(kino_Stepper *self, struct kino_InStream *instream);
KINO_METHOD("Kino_Stepper_Dump");

/* As Stepper_Dump above, but write to an OutStream rather than stdout.
 */
void
kino_Stepper_dump_to_file(kino_Stepper *self, struct kino_InStream *instream,
                          struct kino_OutStream *outstream);
KINO_METHOD("Kino_Stepper_Dump_To_File");

KINO_END_CLASS

#endif /* H_KINO_STEPPER */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

