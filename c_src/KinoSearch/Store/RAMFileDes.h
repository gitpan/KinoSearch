#ifndef H_KINO_RAMFILEDES
#define H_KINO_RAMFILEDES 1

#include "KinoSearch/Store/FileDes.r"

typedef struct kino_RAMFileDes kino_RAMFileDes;
typedef struct KINO_RAMFILEDES_VTABLE KINO_RAMFILEDES_VTABLE;

struct kino_ByteBuf;

KINO_CLASS("KinoSearch::Store::RAMFileDes", "RAMFileDes", 
    "KinoSearch::Store::FileDes");

struct kino_RAMFileDes {
    KINO_RAMFILEDES_VTABLE *_;
    KINO_FILEDES_MEMBER_VARS;
    struct kino_VArray *buffers;
    chy_u64_t len;
};

/* Return a ByteBuf whose string is a copy of the ram file's contents.
 */
struct kino_ByteBuf*
kino_RAMFileDes_contents(kino_RAMFileDes *self);
KINO_METHOD("Kino_RAMFileDes_Contents");

void
kino_RAMFileDes_destroy(kino_RAMFileDes *self);
KINO_METHOD("Kino_RAMFileDes_Destroy");

chy_bool_t
kino_RAMFileDes_fdseek(kino_RAMFileDes *self, chy_u64_t target);
KINO_METHOD("Kino_RAMFileDes_FDSeek");

chy_bool_t
kino_RAMFileDes_fdread(kino_RAMFileDes *self, char *dest, 
                       chy_u32_t dest_offset, chy_u32_t len);
KINO_METHOD("Kino_RAMFileDes_FDRead");

chy_bool_t
kino_RAMFileDes_fdwrite(kino_RAMFileDes *self, const char* buf, 
                        chy_u32_t len);
KINO_METHOD("Kino_RAMFileDes_FDWrite");

chy_u64_t
kino_RAMFileDes_fdlength(kino_RAMFileDes *self);
KINO_METHOD("Kino_RAMFileDes_FDLength");

chy_bool_t
kino_RAMFileDes_fdclose(kino_RAMFileDes *self);
KINO_METHOD("Kino_RAMFileDes_FDClose");

/* Constructor.
 */
kino_RAMFileDes*
kino_RAMFileDes_new(const char *path);

KINO_END_CLASS

#endif /* H_KINO_RAMFILEDES */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

