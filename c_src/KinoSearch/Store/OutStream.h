#ifndef H_KINO_OUTSTREAM
#define H_KINO_OUTSTREAM 1

#include "stddef.h"
#include "KinoSearch/Util/Obj.r"

typedef struct kino_OutStream kino_OutStream;
typedef struct KINO_OUTSTREAM_VTABLE KINO_OUTSTREAM_VTABLE;

struct kino_FileDes;
struct kino_InStream;

KINO_FINAL_CLASS("KinoSearch::Store::OutStream", "OutStream", 
    "KinoSearch::Util::Obj");

struct kino_OutStream {
    KINO_OUTSTREAM_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    char         *buf;
    chy_u64_t     buf_start;
    chy_u32_t     buf_pos;

    struct kino_FileDes *file_des;
    chy_bool_t           is_closed;
};

/* Seek the stream to [target].
 */
void 
kino_OutStream_sseek(kino_OutStream *self, chy_u64_t target);
KINO_METHOD("Kino_OutStream_SSeek");

/* Return the current file position. 
 */
chy_u64_t 
kino_OutStream_stell(kino_OutStream *self);
KINO_METHOD("Kino_OutStream_STell");

/* Flush output buffer to target FileDes.
 */
void
kino_OutStream_sflush(kino_OutStream *self);
KINO_METHOD("Kino_OutStream_SFlush");

/* Return the current length of the file in bytes.
 */
chy_u64_t 
kino_OutStream_slength(kino_OutStream *self);
KINO_METHOD("Kino_OutStream_SLength");

/* Write a single byte to the OutStream. 
 */
void
kino_OutStream_write_byte(kino_OutStream *self, char aChar);
KINO_METHOD("Kino_OutStream_Write_Byte");

/* Write [len] bytes from [buf] to the OutStream.
 */
void
kino_OutStream_write_bytes(kino_OutStream *self, const char *buf, size_t len);
KINO_METHOD("Kino_OutStream_Write_Bytes");

/* Write a 32-bit integer in big-endian byte-order.
 */
void
kino_OutStream_write_int(kino_OutStream *self, chy_u32_t);
KINO_METHOD("Kino_OutStream_Write_Int");

/* Write a 64-bit integer in big-endian byte-order.
 */
void
kino_OutStream_write_long(kino_OutStream *self, chy_u64_t);
KINO_METHOD("Kino_OutStream_Write_Long");

/* Write a 32-bit integer using a compressed format.
 */
void
kino_OutStream_write_vint(kino_OutStream *self, chy_u32_t);
KINO_METHOD("Kino_OutStream_Write_VInt");

/* Write a 64-bit integer using a compressed format.
 */
void
kino_OutStream_write_vlong(kino_OutStream *self, chy_u64_t);
KINO_METHOD("Kino_OutStream_Write_VLong");

/* Write a string as a VInt indicating length of content in bytes, followed by
 * the content.
 */
void
kino_OutStream_write_string(kino_OutStream *self, const char *buf, 
                            size_t len);
KINO_METHOD("Kino_OutStream_Write_String");

/* Write the entire contents of an instream to an outstream.
 */
void 
kino_OutStream_absorb(kino_OutStream *self, struct kino_InStream *instream);
KINO_METHOD("Kino_OutStream_Absorb");

/* Close down the stream.
 */
void
kino_OutStream_sclose(kino_OutStream *self);
KINO_METHOD("Kino_OutStream_SClose");

void
kino_OutStream_destroy(kino_OutStream *self);
KINO_METHOD("Kino_OutStream_Destroy");

/* Constructor.
 */
kino_OutStream*
kino_OutStream_new(struct kino_FileDes *file_des);

KINO_END_CLASS

#endif /* H_KINO_OUTSTREAM */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

