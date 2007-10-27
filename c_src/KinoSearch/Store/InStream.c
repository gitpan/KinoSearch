#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_INSTREAM_VTABLE
#include "KinoSearch/Store/InStream.r"

#include "KinoSearch/Store/FileDes.r"

/* Shared constructor code.  [filename] will be used as is.
 */
static InStream*
do_new(FileDes *file_des, ByteBuf *filename, u64_t offset, u64_t len);

static void
refill(InStream *self);

static void
read_internal(InStream *self, char *dest, u32_t dest_offset, u32_t len);

InStream*
InStream_new(FileDes *file_des)
{
    u64_t len = FileDes_FDLength(file_des);
    ByteBuf *filename = BB_new_str(file_des->path, strlen(file_des->path));
    return do_new(file_des, filename, 0, len);
}

InStream*
InStream_reopen(InStream *self, const ByteBuf *sub_file, u64_t offset, 
                u64_t len)
{
    FileDes *const file_des = self->file_des;
    ByteBuf *filename = sub_file == NULL 
        ? BB_CLONE(self->filename)
        : BB_CLONE(sub_file);
    return do_new(file_des, filename, offset, len);
}

static InStream*
do_new(FileDes *file_des, ByteBuf *filename, u64_t offset, u64_t len)
{
    CREATE(self, InStream, INSTREAM);

    /* init */
    self->buf           = NULL;
    self->buf_start     = 0;
    self->buf_len       = 0;
    self->buf_pos       = 0;

    /* assign */
    self->filename  = filename;  /* use argument; no refcount incrementing */
    self->file_des  = REFCOUNT_INC(file_des);
    self->offset    = offset;
    self->len       = len;

    /* increment */
    self->file_des->stream_count++;

    return self;
}

void
InStream_destroy(InStream *self)
{
    REFCOUNT_DEC(self->file_des);
    REFCOUNT_DEC(self->filename);
    free(self->buf);
    free(self);
}

static void
refill(InStream *self) 
{
    /* wait to allocate buffer until it's needed */
    if (self->buf == NULL) {
        self->buf = MALLOCATE(KINO_IO_STREAM_BUF_SIZE, char);
    }

    /* add bytes read to file position, reset */
    self->buf_start += self->buf_pos;
    self->buf_pos = 0;

    /* calculate the number of bytes to read */
    if ( IO_STREAM_BUF_SIZE + self->buf_start <= InStream_SLength(self) ) {
        self->buf_len = IO_STREAM_BUF_SIZE;
    }
    else {
        const u64_t file_len = InStream_SLength(self);
        if (self->buf_start >= file_len) {
            CONFESS("Read past EOF of %s (start: %lu len %lu)",
                self->filename->ptr, (unsigned long)self->buf_start, 
                (unsigned long)file_len);
        }
        self->buf_len = file_len - self->buf_start;
    }

    /* read bytes from file_des into buffer */
    read_internal(self, self->buf, 0, self->buf_len);
}

static void
read_internal(InStream *self, char *dest, u32_t dest_offset, u32_t len)
{
    FileDes *file_des = self->file_des;

    u64_t position = InStream_STell(self) + self->offset;

    if (file_des->pos != position) {
        if ( !FileDes_FDSeek(file_des, position) ) {
            CONFESS("Error for '%s': %s", self->filename->ptr, Carp_kerror);
        }
    }

    if ( !FileDes_FDRead(file_des, dest, dest_offset, len) )
        CONFESS("Error for '%s': %s", self->filename->ptr, Carp_kerror);
}

void
InStream_sseek(InStream *self, u64_t target) 
{
    /* seek within buffer if possible */
    if (   (target >= self->buf_start)
        && (target <  (self->buf_start + self->buf_pos))
    ) {
        self->buf_pos = target - self->buf_start;
    }
    /* nope, not possible, so seek within file and prepare to refill */
    else {
        self->buf_start = target;
        self->buf_pos   = 0;
        self->buf_len   = 0;
    }
}

u64_t
InStream_stell(InStream *self) 
{
    return self->buf_start + self->buf_pos;
}

char
InStream_read_byte(InStream *self) 
{
    if (self->buf_pos >= self->buf_len)
        refill(self);
    return self->buf[ self->buf_pos++ ];
}

void
InStream_read_bytes (InStream *self, char* buf, size_t len) 
{
    size_t available = self->buf_len - self->buf_pos;
    if (available >= len) {
        /* request is entirely within buffer, so copy */
        memcpy(buf, (self->buf + self->buf_pos), len);
        self->buf_pos += len;
    }
    else { 
        if (available) {
            /* pass along whatever we've got in the buffer */
            memcpy(buf, (self->buf + self->buf_pos), available);
            buf += available;
            len -= available;
            self->buf_pos += available;
        }
        if (len < KINO_IO_STREAM_BUF_SIZE) {
            refill(self);
            if (self->buf_len < len) {
                CONFESS("Read past EOF of %s (start: %lu"
                    " len %lu req: %lu)", self->file_des->path, 
                    (unsigned long)self->buf_start, 
                    (unsigned long)self->buf_len, (unsigned long)len
                );
            }
            memcpy(buf, (self->buf + self->buf_pos), len);
            self->buf_pos += len;
        }
        else {
            read_internal(self, buf, 0, len);
            self->buf_start += len;

            /* trigger refill on read */
            self->buf_start += self->buf_pos;
            self->buf_pos   = 0;
            self->buf_len   = 0;
        }
    }
}

void
InStream_read_byteso(InStream *self, char *buf, size_t start, size_t len) 
{
    buf += start;
    InStream_Read_Bytes(self, buf, len);
}

u32_t
InStream_read_int (InStream *self) 
{
    u32_t retval;
    InStream_Read_Bytes(self, (char*)&retval, 4);
#ifdef LITTLE_END 
    MATH_DECODE_U32(retval, &retval);
#endif
    return retval;
}

u64_t
InStream_read_long (InStream *self) 
{
    u8_t buf[8];
    u64_t aQuad;
    u32_t scratch;

    /* get 8 bytes from the stream */
    InStream_Read_Bytes(self, (char*)buf, 8);

    MATH_DECODE_U32(aQuad, buf);
    aQuad <<= 32;
    MATH_DECODE_U32(scratch, (buf + 4));
    aQuad |= scratch;

    return aQuad;
}

u32_t 
InStream_read_vint (InStream *self) 
{
    u32_t aU32 = 0;
    while (1) {
        const u8_t aUByte = (u8_t)InStream_Read_Byte(self);
        aU32 = (aU32 << 7) | (aUByte & 0x7f);
        if ((aUByte & 0x80) == 0)
            break;
    }
    return aU32;
}

u64_t 
InStream_read_vlong (InStream *self) 
{
    u64_t aQuad = 0;
    while (1) {
        const u8_t aUByte = (u8_t)InStream_Read_Byte(self);
        aQuad = (aQuad << 7) | (aUByte & 0x7f);
        if ((aUByte & 0x80) == 0)
            break;
    }
    return aQuad;
}

int
InStream_read_raw_vlong (InStream *self, char *buf) 
{
    u8_t *dest = (u8_t*)buf;
    do {
        *dest = (u8_t)InStream_Read_Byte(self);
    } while ((*dest++ & 0x80) != 0);
    return dest - (u8_t*)buf;
}

u64_t
InStream_slength(InStream *self)
{
    return self->len;
}

InStream*
InStream_clone(InStream *self)
{
    InStream *evil_twin
        = InStream_Reopen(self, self->filename, self->offset, self->len);

    if (self->buf != NULL) {
        evil_twin->buf = MALLOCATE(KINO_IO_STREAM_BUF_SIZE, char);
        memcpy(evil_twin->buf, self->buf, KINO_IO_STREAM_BUF_SIZE);
    }

    return evil_twin;
}

void
InStream_sclose(InStream *self)
{
    if (--self->file_des->stream_count == 0) {
        if ( !FileDes_FDClose(self->file_des) ) {
            CONFESS("Error for '%s': %s", self->filename->ptr, Carp_kerror);
        }
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

