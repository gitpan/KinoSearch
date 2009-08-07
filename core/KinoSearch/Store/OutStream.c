#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Store/FileDes.h"
#include "KinoSearch/Store/InStream.h"

static INLINE void
SI_flush(OutStream *self);

static INLINE void
SI_write_bytes(OutStream *self, const void *bytes, size_t len);

static INLINE void
SI_write_c32(OutStream *self, u32_t value);

OutStream*
OutStream_new(FileDes *file_des) 
{
    OutStream *self = (OutStream*)VTable_Make_Obj(OUTSTREAM);
    return OutStream_init(self, file_des);
}

OutStream*
OutStream_init(OutStream *self, FileDes *file_des)
{
    /* Init. */
    self->buf = MALLOCATE(IO_STREAM_BUF_SIZE, char);
    self->buf_start   = 0;
    self->buf_pos     = 0;

    /* Assign. */
    self->file_des = (FileDes*)INCREF(file_des); 
    self->path     = CB_Clone(FileDes_Get_Path(file_des));

    return self;
}

void
OutStream_destroy(OutStream *self) 
{
    if (self->file_des != NULL) {
        SI_flush(self);
        DECREF(self->file_des);
    }
    DECREF(self->path);
    FREEMEM(self->buf);
    FREE_OBJ(self);
}

void 
OutStream_absorb(OutStream *self, InStream *instream) 
{
    char buf[IO_STREAM_BUF_SIZE];
    u64_t  bytes_left = InStream_Length(instream);

    while (bytes_left) {
        const u32_t bytes_this_iter = bytes_left < IO_STREAM_BUF_SIZE
            ? (u32_t)bytes_left
            : IO_STREAM_BUF_SIZE;
        InStream_Read_Bytes(instream, buf, bytes_this_iter);
        SI_write_bytes(self, buf, bytes_this_iter);
        bytes_left -= bytes_this_iter;
    }
}

u64_t
OutStream_tell(OutStream *self) 
{
    return self->buf_start + self->buf_pos;
}

void
OutStream_flush(OutStream *self) 
{
    SI_flush(self);
}

static INLINE void
SI_flush(OutStream *self)
{
    if (self->file_des == NULL)
        THROW(ERR, "Can't write to a closed OutStream for %o", self->path);
    if ( !FileDes_Write(self->file_des, self->buf, self->buf_pos) ) {
        THROW(ERR, "Error: %o", FileDes_Get_Mess(self->file_des));
    }
    self->buf_start += self->buf_pos;
    self->buf_pos = 0;
}

u64_t
OutStream_length(OutStream *self) 
{
    SI_flush(self);
    return FileDes_Length(self->file_des);
}

void
OutStream_write_bytes(OutStream *self, const void *bytes, size_t len) 
{
    SI_write_bytes(self, bytes, len);
}

static INLINE void
SI_write_bytes(OutStream *self, const void *bytes, size_t len) 
{
    /* If this data is larger than the buffer size, flush and write. */
    if (len >= IO_STREAM_BUF_SIZE) {
        SI_flush(self);
        if ( !FileDes_Write(self->file_des, bytes, len) ) 
            THROW(ERR, "Error: %o", FileDes_Get_Mess(self->file_des));
        self->buf_start += len;
    }
    /* If there's not enough room in the buffer, flush then add. */
    else if (self->buf_pos + len >= IO_STREAM_BUF_SIZE) {
        SI_flush(self);
        memcpy((self->buf + self->buf_pos), bytes, len);
        self->buf_pos += len;
    }
    /* If there's room, just add these bytes to the buffer. */
    else {
        memcpy((self->buf + self->buf_pos), bytes, len);
        self->buf_pos += len;
    }
}

static INLINE void
SI_write_u8(OutStream *self, u8_t value)
{
    if (self->buf_pos >= IO_STREAM_BUF_SIZE)
        SI_flush(self);
    self->buf[ self->buf_pos++ ] = (char)value;
}

void
OutStream_write_i8(OutStream *self, i8_t value) 
{
    SI_write_u8(self, (u8_t)value);
}

void
OutStream_write_u8(OutStream *self, u8_t value) 
{
    SI_write_u8(self, value);
}

static INLINE void 
SI_write_u32(OutStream *self, u32_t value) 
{
#ifdef BIG_END
    SI_write_bytes(self, &value, 4);
#else 
    char  buf[4];
    char *buf_copy = buf;
    Math_encode_bigend_u32(value, &buf_copy);
    SI_write_bytes(self, buf, 4);
#endif
}

void 
OutStream_write_i32(OutStream *self, i32_t value) 
{
    SI_write_u32(self, (u32_t)value);
}

void 
OutStream_write_u32(OutStream *self, u32_t value) 
{
    SI_write_u32(self, value);
}

static INLINE void
SI_write_u64(OutStream *self, u64_t value) 
{
    u8_t buf[8];

    /* Store as big-endian. */
    buf[0] = (value >> 56) & 0xFF;
    buf[1] = (value >> 48) & 0xFF;
    buf[2] = (value >> 40) & 0xFF;
    buf[3] = (value >> 32) & 0xFF;
    buf[4] = (value >> 24) & 0xFF;
    buf[5] = (value >> 16) & 0xFF;
    buf[6] = (value >> 8 ) & 0xFF;
    buf[7] = (value      ) & 0xFF;

    /* Print encoded Long to the output handle. */
    SI_write_bytes(self, buf, 8);
}

void 
OutStream_write_i64(OutStream *self, i64_t value) 
{
    SI_write_u64(self, (u64_t)value);
}

void 
OutStream_write_u64(OutStream *self, u64_t value) 
{
    SI_write_u64(self, value);
}

void 
OutStream_write_f32(OutStream *self, float value) 
{
#ifdef BIG_END
    SI_write_bytes(self, &value, sizeof(float));
#else 
    char  buf[sizeof(float)];
    char *buf_copy = buf;
    union { float f; u32_t u32; } duo; 
    duo.f = value;
    Math_encode_bigend_u32(duo.u32, &buf_copy);
    SI_write_bytes(self, buf, sizeof(float));
#endif
}

void 
OutStream_write_f64(OutStream *self, double value) 
{
#ifdef BIG_END
    SI_write_bytes(self, &value, sizeof(double));
#else 
    char  buf[sizeof(double)];
    char *buf_copy = buf;
    union { double f; u64_t u64; } duo; 
    duo.f = value;
    Math_encode_bigend_u64(duo.u64, &buf_copy);
    SI_write_bytes(self, buf, sizeof(double));
#endif
}

void
OutStream_write_c32(OutStream *self, u32_t value) 
{
    SI_write_c32(self, value);
}

static INLINE void
SI_write_c32(OutStream *self, u32_t value) 
{
    u8_t buf[C32_MAX_BYTES];
    u8_t *ptr = buf + sizeof(buf) - 1;

    /* Write last byte first, which has no continue bit. */
    *ptr = value & 0x7f;
    value >>= 7;
    
    while (value) {
        /* Work backwards, writing bytes with continue bits set. */
        *--ptr = ((value & 0x7f) | 0x80);
        value >>= 7;
    }

    SI_write_bytes(self, ptr, (buf + sizeof(buf)) - ptr);
}

void
OutStream_write_c64(OutStream *self, u64_t value) 
{
    u8_t buf[C64_MAX_BYTES];
    u8_t *ptr = buf + sizeof(buf) - 1;

    /* Write last byte first, which has no continue bit. */
    *ptr = value & 0x7f;
    value >>= 7;
    
    while (value) {
        /* Work backwards, writing bytes with continue bits set. */
        *--ptr = ((value & 0x7f) | 0x80);
        value >>= 7;
    }

    SI_write_bytes(self, ptr, (buf + sizeof(buf)) - ptr);
}

void
OutStream_write_string(OutStream *self, const char *string, size_t len) 
{
    SI_write_c32(self, (u32_t)len);
    SI_write_bytes(self, string, len);
}

void
OutStream_close(OutStream *self)
{
    SI_flush(self);
    DECREF(self->file_des);
    self->file_des = NULL;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

