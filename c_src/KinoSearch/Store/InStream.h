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
    kino_u64_t   offset;
    kino_u64_t   len;
    char        *buf;          
    kino_u64_t   buf_start;    /* file position of start of buffer */
    kino_u32_t   buf_len;      /* number of valid bytes in the buffer */
    kino_u32_t   buf_pos;      /* next byte to read */

    struct kino_FileDes *file_des;
};

/* Seek to target plus the object's start offset.
 */
KINO_METHOD("Kino_InStream_SSeek",
void 
kino_InStream_sseek (kino_InStream *self, kino_u64_t target));

/* Return the filehandle's position minus the offset.
 */
KINO_METHOD("Kino_InStream_STell",
kino_u64_t
kino_InStream_stell(kino_InStream *self));

/* Read one byte from the instream and return it as a char.
 */
KINO_METHOD("Kino_InStream_Read_Byte",
char
kino_InStream_read_byte(kino_InStream *self));

/* Read [len] bytes from into [buf]. 
 */
KINO_METHOD("Kino_InStream_Read_Bytes",
void
kino_InStream_read_bytes(kino_InStream *self, char *buf, size_t len));

/* This is just a wrapper for read_bytes, but that may change.  It should
 * be used whenever Lucene character data is being read, typically after
 * read_vint as part of a String read. If and when a change does come, it will
 * be a lot easier to track down all the relevant code fragments if read_chars
 * gets used consistently. 
 */
KINO_METHOD("Kino_InStream_Read_Chars",
void
kino_InStream_read_chars(kino_InStream *self, char *buf, size_t start, 
                         size_t len));

/* Read a 32-bit integer from the InStream.
 */
KINO_METHOD("Kino_InStream_Read_Int",
kino_u32_t
kino_InStream_read_int(kino_InStream *self));

/* Read a 64-bit integer from the InStream.
 */
KINO_METHOD("Kino_InStream_Read_Long",
kino_u64_t
kino_InStream_read_long(kino_InStream *self));

/* Read in a Variable INTeger, stored in 1-5 bytes.
 */
KINO_METHOD("Kino_InStream_Read_VInt",
kino_u32_t
kino_InStream_read_vint(kino_InStream *self));

/* Read 64-bit integer from the instream, using the same encoding as a VInt
 * but possibly occupying as many as 10 bytes.
 */
KINO_METHOD("Kino_InStream_Read_VLong",
kino_u64_t
kino_InStream_read_vlong(kino_InStream *self));

/* Return the length of the "file" in bytes.
 */
KINO_METHOD("Kino_InStream_SLength",
kino_u64_t
kino_InStream_slength(kino_InStream *self));

/* Clone the instream, but specify a new offset and length.
 */
KINO_METHOD("Kino_InStream_Reopen",
kino_InStream*
kino_InStream_reopen(kino_InStream *self, kino_u64_t offset, kino_u64_t len));

/* Decrement the number of streams using the underlying FileDes.  When the
 * number drops to zero, possibly release system resources.
 */
KINO_METHOD("Kino_InStream_SClose",
void
kino_InStream_sclose(kino_InStream *self));

/* Clone the instream; clones are able to seek and read independently.
 */
KINO_METHOD("Kino_InStream_Clone",
kino_InStream*
kino_InStream_clone(kino_InStream *self));

KINO_METHOD("Kino_InStream_Destroy",
void
kino_InStream_destroy(kino_InStream *self));

/* Constructor. 
 */
KINO_FUNCTION(
kino_InStream*
kino_InStream_new(struct kino_FileDes *file_des));

/* Read a varible integer from the buffer pointed to by the source pointer.
 * While reading, advance the pointer, consuming the bytes occupied by the
 * VInt.  (This is sort of an ugly hack, but no better solution has presented
 * itself.)
 */
KINO_FUNCTION(
kino_u32_t
kino_InStream_decode_vint(char **source_ptr));

KINO_END_CLASS

#endif /* H_KINO_INSTREAM */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

