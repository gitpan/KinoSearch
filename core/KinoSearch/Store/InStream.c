#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/FileDes.h"
#include "KinoSearch/Store/FileWindow.h"

static INLINE void
SI_fill(InStream *self, i64_t amount);

static INLINE void
SI_refill(InStream *self);

static INLINE void
SI_read_bytes (InStream *self, char* buf, size_t len);

static INLINE u8_t
SI_read_u8(InStream *self);

InStream*
InStream_new(FileDes *file_des)
{
    InStream *self = (InStream*)VTable_Make_Obj(INSTREAM);
    return InStream_init(self, file_des);
}

InStream*
InStream_init(InStream *self, FileDes *file_des)
{
    /* Init. */
    self->buf           = NULL;
    self->limit         = NULL;
    self->offset        = 0;
    self->window        = FileWindow_new(NULL, 0, 0, 0);

    /* Assign. */
    self->file_des      = (FileDes*)INCREF(file_des);

    /* Derive. */
    self->len           = FileDes_Length(file_des);
    self->filename      = CB_Clone(FileDes_Get_Path(file_des));

    return self;
}

void
InStream_close(InStream *self)
{
    if (self->file_des) {
        FileDes_Release_Window(self->file_des, self->window);
        DECREF(self->file_des);
        self->file_des = NULL;
    }
}

void
InStream_destroy(InStream *self)
{
    if (self->file_des) {
        InStream_Close(self);
    }
    DECREF(self->filename);
    DECREF(self->window);
    FREE_OBJ(self);
}

InStream*
InStream_reopen(InStream *self, const CharBuf *sub_file, i64_t offset, 
                i64_t len)
{
    InStream *evil_twin = (InStream*)VTable_Make_Obj(self->vtable);
    InStream_init(evil_twin, self->file_des);
    if (sub_file != NULL) CB_Mimic(evil_twin->filename, (Obj*)sub_file);
    evil_twin->offset = offset;
    evil_twin->len    = len;
    InStream_Seek(evil_twin, 0);
    return evil_twin;
}

InStream*
InStream_clone(InStream *self)
{
    InStream *evil_twin = (InStream*)VTable_Make_Obj(self->vtable);
    InStream_init(evil_twin, self->file_des);
    InStream_Seek(evil_twin, InStream_Tell(self));
    return evil_twin;
}

CharBuf*
InStream_get_filename(InStream *self) { return self->filename; }

static INLINE void
SI_refill(InStream *self) 
{
    const i64_t sub_file_pos = InStream_tell(self);
    const i64_t remaining    = self->len - sub_file_pos;
    const i64_t amount       = remaining < IO_STREAM_BUF_SIZE 
                             ? remaining 
                             : IO_STREAM_BUF_SIZE;
    if (!remaining) {
        THROW(ERR, "Read past EOF of '%o' (offset: %i64 len: %i64)",
            self->filename, self->offset, self->len);
    }
    SI_fill(self, amount);
}

void
InStream_refill(InStream *self)
{
    SI_refill(self);
}

static INLINE void
SI_fill(InStream *self, i64_t amount) 
{
    FileWindow *const window     = self->window;
    const i64_t virtual_file_pos = InStream_tell(self);
    const i64_t real_file_pos    = virtual_file_pos + self->offset;
    const i64_t remaining        = self->len - virtual_file_pos;

    if (amount > remaining) {
        THROW(ERR,  "Read past EOF of %o (pos: %u64 len: %u64 request: %u64)",
            self->filename, virtual_file_pos, self->len, amount);
    }

    if (FileDes_Window(self->file_des, window, real_file_pos, amount) ) {
        char *const window_limit = window->buf + window->len;
        self->buf = window->buf 
                  - window->offset    /* theoretical start of real file */
                  + self->offset      /* top of virtual file */
                  + virtual_file_pos; /* position within virtual file */
        self->limit = window_limit - self->buf > remaining
                    ? self->buf + remaining
                    : window_limit;
    }
    else {
        THROW(ERR, "Error for '%o': %o", self->filename, 
            FileDes_Get_Mess(self->file_des));
    }
}

void
InStream_fill(InStream *self, i64_t amount)
{
    SI_fill(self, amount);
}

void
InStream_seek(InStream *self, i64_t target) 
{
    FileWindow *const window = self->window;
    i64_t virtual_window_top = window->offset - self->offset;
    i64_t virtual_window_end = virtual_window_top + window->len;

    if (target < 0) {
        THROW(ERR, "Can't Seek to negative target %i64", target);
    }
    /* Seek within window if possible. */
    else if (   target >= virtual_window_top
             && target <= virtual_window_end
    ) {
        self->buf = window->buf - window->offset + self->offset + target;
    }
    else {
        /* Target is outside window.  Set all buffer and limit variables to
         * NULL to trigger refill on the next read.  Store the file position
         * in the FileWindow's offset. */
        FileDes_Release_Window(self->file_des, window);
        self->buf = NULL;
        self->limit = NULL;
        FileWindow_Set_Offset(window, self->offset + target);
    }
}

i64_t
InStream_tell(InStream *self) 
{
    FileWindow *const window = self->window;
    i64_t pos_in_buf = PTR2I64(self->buf) - PTR2I64(window->buf);
    return pos_in_buf + window->offset - self->offset;
}

i64_t
InStream_length(InStream *self)
{
    return self->len;
}

char*
InStream_buf(InStream *self, size_t request)
{
    const i64_t bytes_in_buf = PTR2I64(self->limit) - PTR2I64(self->buf);

    if ((i64_t)request > bytes_in_buf) {
        const i64_t remaining_in_file = self->len - InStream_Tell(self);
        i64_t amount = request;

        /* Try to bump up small requests. */
        if (amount < self->window->cap)  amount = self->window->cap;
        if (amount < IO_STREAM_BUF_SIZE) amount = IO_STREAM_BUF_SIZE;

        /* Don't read past EOF. */
        if (remaining_in_file < amount) amount = remaining_in_file; 

        if (amount > bytes_in_buf) { 
            SI_fill(self, amount); 
        }
    }

    return self->buf;
}

void
InStream_advance_buf(InStream *self, char *buf)
{
    if (buf > self->limit) {
        i64_t overrun = PTR2I64(buf) - PTR2I64(self->limit);
        THROW(ERR, "Supplied value is %i64 bytes beyond end of buffer",
            overrun);
    }
    else if (buf < self->buf) {
        i64_t underrun = PTR2I64(self->buf) - PTR2I64(buf);
        THROW(ERR, "Can't Advance_Buf backwards: (underrun: %i64))", underrun);
    }
    else {
        self->buf = buf;
    }
}

void
InStream_read_bytes(InStream *self, char* buf, size_t len) 
{
    SI_read_bytes(self, buf, len);
}

static INLINE void
SI_read_bytes(InStream *self, char* buf, size_t len) 
{
    const i64_t available = PTR2I64(self->limit) - PTR2I64(self->buf);
    if (available >= (i64_t)len) {
        /* Request is entirely within buffer, so copy. */
        memcpy(buf, self->buf, len);
        self->buf += len;
    }
    else { 
        /* Pass along whatever we've got in the buffer. */
        if (available > 0) {
            memcpy(buf, self->buf, (size_t)available);
            buf += available;
            len -= (size_t)available;
            self->buf += available;
        }

        if (len < IO_STREAM_BUF_SIZE) {
            /* Ensure that we have enough mapped, then copy the rest. */
            SI_refill(self);
            memcpy(buf, self->buf, len);
            self->buf += len;
        }
        else {
            const i64_t sub_file_pos = InStream_tell(self);
            const i64_t real_file_pos = sub_file_pos + self->offset;
            bool_t success 
                = FileDes_Read(self->file_des, buf, real_file_pos, len);
            if (!success) {
                THROW(ERR, "%o", FileDes_Get_Mess(self->file_des));
            }
            InStream_seek(self, sub_file_pos + len);
        }
    }
}

void
InStream_read_byteso(InStream *self, char *buf, size_t start, size_t len) 
{
    buf += start;
    SI_read_bytes(self, buf, len);
}

i8_t
InStream_read_i8(InStream *self)
{
    return (i8_t)SI_read_u8(self);
}

static INLINE u8_t
SI_read_u8(InStream *self)
{
    if (self->buf >= self->limit) { SI_refill(self); }
    return (u8_t)*self->buf++;
}

u8_t
InStream_read_u8(InStream *self)
{
    return SI_read_u8(self);
}

static INLINE u32_t
SI_read_u32 (InStream *self) 
{
    u32_t retval;
    SI_read_bytes(self, (char*)&retval, 4);
#ifdef LITTLE_END 
    retval = Math_decode_bigend_u32((char*)&retval);
#endif
    return retval;
}

u32_t
InStream_read_u32(InStream *self)
{
    return SI_read_u32(self);
}

i32_t
InStream_read_i32(InStream *self)
{
    return (i32_t)SI_read_u32(self);
}

static INLINE u64_t
SI_read_u64 (InStream *self) 
{
    u64_t retval;
    SI_read_bytes(self, (char*)&retval, 8);
#ifdef LITTLE_END 
    retval = Math_decode_bigend_u64((char*)&retval);
#endif
    return retval;
}

u64_t
InStream_read_u64(InStream *self)
{
    return SI_read_u64(self);
}

i64_t
InStream_read_i64(InStream *self)
{
    return (i64_t)SI_read_u64(self);
}

float
InStream_read_f32(InStream *self)
{
    union { float f; u32_t u32; } retval;
    SI_read_bytes(self, (char*)&retval, sizeof(float));
#ifdef LITTLE_END 
    retval.u32 = Math_decode_bigend_u32((char*)&retval.u32);
#endif
    return retval.f;
}

double
InStream_read_f64(InStream *self)
{
    union { double f; u64_t u64; } retval;
    SI_read_bytes(self, (char*)&retval, sizeof(double));
#ifdef LITTLE_END 
    retval.u64 = Math_decode_bigend_u64((char*)&retval.u64);
#endif
    return retval.f;
}

u32_t 
InStream_read_c32 (InStream *self) 
{
    u32_t retval = 0;
    while (1) {
        const u8_t ubyte = SI_read_u8(self);
        retval = (retval << 7) | (ubyte & 0x7f);
        if ((ubyte & 0x80) == 0)
            break;
    }
    return retval;
}

u64_t 
InStream_read_c64 (InStream *self) 
{
    u64_t retval = 0;
    while (1) {
        const u8_t ubyte = SI_read_u8(self);
        retval = (retval << 7) | (ubyte & 0x7f);
        if ((ubyte & 0x80) == 0)
            break;
    }
    return retval;
}

int
InStream_read_raw_c64 (InStream *self, char *buf) 
{
    u8_t *dest = (u8_t*)buf;
    do {
        *dest = SI_read_u8(self);
    } while ((*dest++ & 0x80) != 0);
    return dest - (u8_t*)buf;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

