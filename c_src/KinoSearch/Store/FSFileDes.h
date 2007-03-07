#ifndef H_KINO_FSFILEDES
#define H_KINO_FSFILEDES 1

#include <stdio.h>

#include "KinoSearch/Store/FileDes.r"

typedef struct kino_FSFileDes kino_FSFileDes;
typedef struct KINO_FSFILEDES_VTABLE KINO_FSFILEDES_VTABLE;

KINO_CLASS("KinoSearch::Store::FSFileDes", "FSFileDes", 
    "KinoSearch::Store::FileDes");

struct kino_FSFileDes {
    KINO_FSFILEDES_VTABLE *_;
    KINO_FILEDES_MEMBER_VARS;
    FILE *fhandle;
};

/* Constructor.
 */
KINO_FUNCTION(
kino_FSFileDes*
kino_FSFileDes_new(const char *mode, const char *class));

KINO_METHOD("Kino_FSFileDes_Destroy",
void
kino_FSFileDes_destroy(kino_FSFileDes *self));

KINO_METHOD("Kino_FSFileDes_FDSeek",
void
kino_FSFileDes_fdseek(kino_FSFileDes *self, kino_u64_t target));

KINO_METHOD("Kino_FSFileDes_FDRead",
void
kino_FSFileDes_fdread(kino_FSFileDes *self, char *dest, 
                      kino_u32_t dest_offset, kino_u32_t len));

KINO_METHOD("Kino_FSFileDes_FDWrite",
void
kino_FSFileDes_fdwrite(kino_FSFileDes *self, char* buf, kino_u32_t len));

KINO_METHOD("Kino_FSFileDes_FDLength",
kino_u64_t
kino_FSFileDes_fdlength(kino_FSFileDes *self));

KINO_METHOD("Kino_FSFileDes_FDClose",
void
kino_FSFileDes_fdclose(kino_FSFileDes *self));

KINO_END_CLASS

#endif /* H_KINO_FSFILEDES */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

