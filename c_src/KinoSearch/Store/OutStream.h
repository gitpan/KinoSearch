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
    kino_u64_t    buf_start;
    kino_u32_t    buf_pos;

    struct kino_FileDes *file_des;
    kino_bool_t          is_closed;
};

/* Seek the stream to [target].
 */
KINO_METHOD("Kino_OutStream_SSeek",
void 
kino_OutStream_sseek(kino_OutStream *self, kino_u64_t target));

/* Return the current file position. 
 */
KINO_METHOD("Kino_OutStream_STell",
kino_u64_t 
kino_OutStream_stell(kino_OutStream *self));

/* Flush output buffer to target FileDes.
 */
KINO_METHOD("Kino_OutStream_SFlush",
void
kino_OutStream_sflush(kino_OutStream *self));

/* Return the current length of the file in bytes.
 */
KINO_METHOD("Kino_OutStream_SLength",
kino_u64_t 
kino_OutStream_slength(kino_OutStream *self));

/* Write a single byte to the OutStream. 
 */
KINO_METHOD("Kino_OutStream_Write_Byte",
void
kino_OutStream_write_byte(kino_OutStream *self, char aChar));

/* Write [len] bytes from [buf] to the OutStream.
 */
KINO_METHOD("Kino_OutStream_Write_Bytes",
void
kino_OutStream_write_bytes(kino_OutStream *self, char *buf, size_t len));

/* Write a 32-bit integer in big-endian byte-order.
 */
KINO_METHOD("Kino_OutStream_Write_Int",
void
kino_OutStream_write_int(kino_OutStream *self, kino_u32_t));

/* Write a 64-bit integer in big-endian byte-order.
 */
KINO_METHOD("Kino_OutStream_Write_Long",
void
kino_OutStream_write_long(kino_OutStream *self, kino_u64_t));

/* Write a 32-bit integer using a compressed format.
 */
KINO_METHOD("Kino_OutStream_Write_VInt",
void
kino_OutStream_write_vint(kino_OutStream *self, kino_u32_t));

/* Write a 64-bit integer using a compressed format.
 */
KINO_METHOD("Kino_OutStream_Write_VLong",
void
kino_OutStream_write_vlong(kino_OutStream *self, kino_u64_t));

/* Write a string as a VInt indicating length of content in bytes, followed by
 * the content.
 */
KINO_METHOD("Kino_OutStream_Write_String",
void
kino_OutStream_write_string(kino_OutStream *self, char *buf, size_t len));

/* Write the entire contents of an instream to an outstream.
 */
KINO_METHOD("Kino_OutStream_Absorb",
void 
kino_OutStream_absorb(kino_OutStream *self, struct kino_InStream *instream));

/* Close down the stream.
 */
KINO_METHOD("Kino_OutStream_SClose",
void
kino_OutStream_sclose(kino_OutStream *self));

KINO_METHOD("Kino_OutStream_Destroy",
void
kino_OutStream_destroy(kino_OutStream *self));

/* Constructor.
 */
KINO_FUNCTION(
kino_OutStream*
kino_OutStream_new(struct kino_FileDes *file_des));

/* Encode a VInt into [buf]. buf must have room for at 5 bytes. Returns the
 * number of bytes consumed.
 */
KINO_FUNCTION(
int
kino_OutStream_encode_vint(kino_u32_t aU32, char *buf));

KINO_END_CLASS

#endif /* H_KINO_OUTSTREAM */


/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

