#ifndef H_KINO_INSTREAM
#define H_KINO_INSTREAM 1

#include <stddef.h>
#include "KinoSearch/Util/Obj.r"

/* Detect whether we're on an ASCII or EBCDIC machine. */
#if '0' == 240
#define KINO_NUM_CHAR_OFFSET 240
#else
#define KINO_NUM_CHAR_OFFSET 48
#endif

typedef struct kino_InStream kino_InStream;
typedef struct KINO_INSTREAM_VTABLE KINO_INSTREAM_VTABLE;

struct kino_FileDes;

KINO_FINAL_CLASS("KinoSearch::Store::InStream", "InStream", 
    "KinoSearch::Util::Obj");

struct kino_InStream {
    KINO_INSTREAM_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    chy_u64_t    offset;
    chy_u64_t    len;
    char        *buf;          
    chy_u64_t    buf_start;    /* file position of start of buffer */
    chy_u32_t    buf_len;      /* number of valid bytes in the buffer */
    chy_u32_t    buf_pos;      /* next byte to read */
    struct kino_ByteBuf *filename; 
    struct kino_FileDes *file_des;
};

/* Seek to target plus the object's start offset.
 */
void 
kino_InStream_sseek (kino_InStream *self, chy_u64_t target);
KINO_METHOD("Kino_InStream_SSeek");

/* Return the filehandle's position minus the offset.
 */
chy_u64_t
kino_InStream_stell(kino_InStream *self);
KINO_METHOD("Kino_InStream_STell");

/* Read one byte from the instream and return it as a char.
 */
char
kino_InStream_read_byte(kino_InStream *self);
KINO_METHOD("Kino_InStream_Read_Byte");

/* Read [len] bytes from into [buf]. 
 */
void
kino_InStream_read_bytes(kino_InStream *self, char *buf, size_t len);
KINO_METHOD("Kino_InStream_Read_Bytes");


/* Read [len] bytes into [buf] starting at [offset].
 */
void
kino_InStream_read_byteso(kino_InStream *self, char *buf, size_t start, 
                          size_t len);
KINO_METHOD("Kino_InStream_Read_BytesO");

/* Read a 32-bit integer from the InStream.
 */
chy_u32_t
kino_InStream_read_int(kino_InStream *self);
KINO_METHOD("Kino_InStream_Read_Int");

/* Read a 64-bit integer from the InStream.
 */
chy_u64_t
kino_InStream_read_long(kino_InStream *self);
KINO_METHOD("Kino_InStream_Read_Long");

/* Read in a Variable INTeger, stored in 1-5 bytes.
 */
chy_u32_t
kino_InStream_read_vint(kino_InStream *self);
KINO_METHOD("Kino_InStream_Read_VInt");

/* Read 64-bit integer from the instream, using the same encoding as a VInt
 * but possibly occupying as many as 10 bytes.
 */
chy_u64_t
kino_InStream_read_vlong(kino_InStream *self);
KINO_METHOD("Kino_InStream_Read_VLong");

/* Read the bytes for a VInt/VLong into [buf].  Return the number of bytes
 * read.  The caller must ensure that sufficient space exists in [buf] (worst
 * case is 10 bytes).
 */
int
kino_InStream_read_raw_vlong(kino_InStream *self, char *buf);
KINO_METHOD("Kino_InStream_Read_Raw_VLong");

/* Return the length of the "file" in bytes.
 */
chy_u64_t
kino_InStream_slength(kino_InStream *self);
KINO_METHOD("Kino_InStream_SLength");

/* Clone the instream, but specify a new offset, length, and possibly
 * filename.  [filename] may be NULL, in which case, the original object's
 * filename will be duped.
 */
kino_InStream*
kino_InStream_reopen(kino_InStream *self, 
                     const struct kino_ByteBuf *filename, 
                     chy_u64_t offset, chy_u64_t len);
KINO_METHOD("Kino_InStream_Reopen");

/* Decrement the number of streams using the underlying FileDes.  When the
 * number drops to zero, possibly release system resources.
 */
void
kino_InStream_sclose(kino_InStream *self);
KINO_METHOD("Kino_InStream_SClose");

/* Clone the instream; clones are able to seek and read independently.
 */
kino_InStream*
kino_InStream_clone(kino_InStream *self);
KINO_METHOD("Kino_InStream_Clone");

void
kino_InStream_destroy(kino_InStream *self);
KINO_METHOD("Kino_InStream_Destroy");

/* Constructor. 
 */
kino_InStream*
kino_InStream_new(struct kino_FileDes *file_des);

KINO_END_CLASS

#endif /* H_KINO_INSTREAM */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

