#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_OUTSTREAM_VTABLE
#include "KinoSearch/Store/OutStream.r"

#include "KinoSearch/Store/FileDes.r"
#include "KinoSearch/Store/InStream.r"

OutStream*
OutStream_new(FileDes *file_des) 
{
    CREATE(self, OutStream, OUTSTREAM);

    /* init */
    self->buf = MALLOCATE(KINO_IO_STREAM_BUF_SIZE, char);
    self->buf_start   = 0;
    self->buf_pos     = 0;
    self->is_closed   = false;

    /* assign */
    self->file_des = REFCOUNT_INC(file_des); 

    /* increment */
    file_des->stream_count++;

    return self;
}

void
OutStream_destroy(OutStream *self) 
{
    if (!self->is_closed)
        OutStream_SFlush(self);
    REFCOUNT_DEC(self->file_des);
    free(self->buf);
    free(self);
}

void 
OutStream_absorb(OutStream *self, InStream *instream) 
{
    char buf[KINO_IO_STREAM_BUF_SIZE];
    u64_t  bytes_left = InStream_SLength(instream);

    while (bytes_left) {
        const u32_t bytes_this_iter = bytes_left < IO_STREAM_BUF_SIZE
            ? bytes_left
            : IO_STREAM_BUF_SIZE;
        InStream_Read_Bytes(instream, buf, bytes_this_iter);
        OutStream_write_bytes(self, buf, bytes_this_iter);
        bytes_left -= bytes_this_iter;
    }
}

u64_t
OutStream_stell(OutStream *self) 
{
    return self->buf_start + self->buf_pos;
}

void
OutStream_sflush(OutStream *self) 
{
    if ( !FileDes_FDWrite(self->file_des, self->buf, self->buf_pos) ) {
        CONFESS("Error: %s", Carp_kerror);
    }
    self->buf_start += self->buf_pos;
    self->buf_pos = 0;
}

u64_t
OutStream_slength(OutStream *self) 
{
    OutStream_SFlush(self);
    return FileDes_FDLength(self->file_des);
}

void
OutStream_write_byte(OutStream *self, char aChar) 
{
    if (self->buf_pos >= KINO_IO_STREAM_BUF_SIZE)
        OutStream_SFlush(self);
    self->buf[ self->buf_pos++ ] = aChar;
}

void
OutStream_write_bytes(OutStream *self, const char *bytes, size_t len) 
{
    /* if this data is larger than the buffer size, flush and write */
    if (len >= KINO_IO_STREAM_BUF_SIZE) {
        OutStream_SFlush(self);
        if ( !FileDes_FDWrite(self->file_des, bytes, len) ) 
            CONFESS("Error: %s", Carp_kerror);
        self->buf_start += len;
    }
    /* if there's not enough room in the buffer, flush then add */
    else if (self->buf_pos + len >= KINO_IO_STREAM_BUF_SIZE) {
        OutStream_SFlush(self);
        memcpy((self->buf + self->buf_pos), bytes, 
            len * sizeof(char));
        self->buf_pos += len;
    }
    /* if there's room, just add these bytes to the buffer */
    else {
        memcpy((self->buf + self->buf_pos), bytes, 
            len * sizeof(char));
        self->buf_pos += len;
    }
}

void 
OutStream_write_int(OutStream *self, u32_t aU32) 
{
#ifdef BIG_END
    OutStream_Write_Bytes(self, (char*)&aU32, 4);
#else 
    u8_t buf[4];
    MATH_ENCODE_U32(aU32, buf);
    OutStream_Write_Bytes(self, (char*)buf, 4);
#endif
}

void
OutStream_write_long(OutStream *self, u64_t aQuad) 
{
    u8_t buf[8];

    /* store as big-endian */
    buf[0] = (aQuad >> 56) & 0xFF;
    buf[1] = (aQuad >> 48) & 0xFF;
    buf[2] = (aQuad >> 40) & 0xFF;
    buf[3] = (aQuad >> 32) & 0xFF;
    buf[4] = (aQuad >> 24) & 0xFF;
    buf[5] = (aQuad >> 16) & 0xFF;
    buf[6] = (aQuad >> 8 ) & 0xFF;
    buf[7] = (aQuad      ) & 0xFF;

    /* print encoded Long to the output handle */
    OutStream_Write_Bytes(self, (char*)buf, 8);
}

void
OutStream_write_vint(OutStream *self, u32_t aU32) 
{
    u8_t buf[VINT_MAX_BYTES];
    u8_t *ptr = buf + sizeof(buf) - 1;

    /* write last byte first, which has no continue bit */
    *ptr = aU32 & 0x7f;
    aU32 >>= 7;
    
    while (aU32) {
        /* work backwards, writing bytes with continue bits set */
        *--ptr = ((aU32 & 0x7f) | 0x80);
        aU32 >>= 7;
    }

    OutStream_write_bytes(self, (char*)ptr, (buf + sizeof(buf)) - ptr);
}

void
OutStream_write_vlong(OutStream *self, u64_t aQuad) 
{
    u8_t buf[VLONG_MAX_BYTES];
    u8_t *ptr = buf + sizeof(buf) - 1;

    /* write last byte first, which has no continue bit */
    *ptr = aQuad & 0x7f;
    aQuad >>= 7;
    
    while (aQuad) {
        /* work backwards, writing bytes with continue bits set */
        *--ptr = ((aQuad & 0x7f) | 0x80);
        aQuad >>= 7;
    }

    OutStream_write_bytes(self, (char*)ptr, (buf + sizeof(buf)) - ptr);
}

void
OutStream_write_string(OutStream *self, const char *string, size_t len) 
{
    OutStream_write_vint(self, (u32_t)len);
    OutStream_write_bytes(self, string, len);
}

void
OutStream_sclose(OutStream *self)
{
    OutStream_SFlush(self);
    if (--self->file_des->stream_count <= 0) {
        if ( !FileDes_FDClose(self->file_des) ) {
            CONFESS("Error closing '%s': %s", self->file_des->path, 
                Carp_kerror);
        }
    }
    self->is_closed = true;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

