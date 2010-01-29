#define C_KINO_INSTREAM
#define C_KINO_FILEWINDOW
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/FileHandle.h"
#include "KinoSearch/Store/FSFileHandle.h"
#include "KinoSearch/Store/FileWindow.h"
#include "KinoSearch/Store/RAMFile.h"
#include "KinoSearch/Store/RAMFileHandle.h"

/* Inlined version of InStream_Tell. */
static INLINE i64_t
SI_tell(InStream *self);

/* Inlined version of InStream_Read_Bytes. */
static INLINE void
SI_read_bytes(InStream *self, char* buf, size_t len);

/* Inlined version of InStream_Read_U8. */
static INLINE u8_t
SI_read_u8(InStream *self);

/* Ensure that the buffer contains exactly the specified amount of data. */
static void
S_fill(InStream *self, i64_t amount);

/* Refill the buffer, with either IO_STREAM_BUF_SIZE bytes or all remaining
 * file content -- whichever is smaller. Throw an error if we're at EOF and
 * can't load at least one byte. */
static void
S_refill(InStream *self);

InStream*
InStream_open(Obj *file)
{
    InStream *self = (InStream*)VTable_Make_Obj(INSTREAM);
    return InStream_do_open(self, file);
}

InStream*
InStream_do_open(InStream *self, Obj *file)
{
    /* Init. */
    self->buf           = NULL;
    self->limit         = NULL;
    self->offset        = 0;
    self->window        = FileWindow_new();

    /* Obtain a FileHandle. */
    if (Obj_Is_A(file, FILEHANDLE)) {
        self->file_handle = (FileHandle*)INCREF(file);
    }
    else if (Obj_Is_A(file, RAMFILE)) {
        self->file_handle 
            = (FileHandle*)RAMFH_open(NULL, FH_READ_ONLY, (RAMFile*)file);
    }
    else if (Obj_Is_A(file, CHARBUF)) {
        self->file_handle 
            = (FileHandle*)FSFH_open((CharBuf*)file, FH_READ_ONLY);
    }
    else {
        Err_set_error(Err_new(CB_newf("Invalid type for param 'file': '%o'",
            Obj_Get_Class_Name(file))));
        DECREF(self);
        return NULL;
    }
    if (!self->file_handle) {
        ERR_ADD_FRAME(Err_get_error());
        DECREF(self);
        return NULL;
    }

    /* Get length and filename from the FileHandle. */ 
    self->filename      = CB_Clone(FH_Get_Path(self->file_handle));
    self->len           = FH_Length(self->file_handle);
    if (self->len == -1) {
        ERR_ADD_FRAME(Err_get_error());
        DECREF(self);
        return NULL;
    }

    return self;
}

void
InStream_close(InStream *self)
{
    if (self->file_handle) {
        FH_Release_Window(self->file_handle, self->window);
        /* Note that we don't close the FileHandle, because it's probably
         * shared. */
        DECREF(self->file_handle);
        self->file_handle = NULL;
    }
}

void
InStream_destroy(InStream *self)
{
    if (self->file_handle) {
        InStream_Close(self);
    }
    DECREF(self->filename);
    DECREF(self->window);
    SUPER_DESTROY(self, INSTREAM);
}

InStream*
InStream_reopen(InStream *self, const CharBuf *filename, i64_t offset, 
                i64_t len)
{
    InStream *evil_twin = (InStream*)VTable_Make_Obj(self->vtable);
    InStream_do_open(evil_twin, (Obj*)self->file_handle);
    if (filename != NULL) { CB_Mimic(evil_twin->filename, (Obj*)filename); }
    evil_twin->offset = offset;
    evil_twin->len    = len;
    InStream_Seek(evil_twin, 0);
    return evil_twin;
}

InStream*
InStream_clone(InStream *self)
{
    InStream *evil_twin = (InStream*)VTable_Make_Obj(self->vtable);
    InStream_do_open(evil_twin, (Obj*)self->file_handle);
    InStream_Seek(evil_twin, SI_tell(self));
    return evil_twin;
}

CharBuf*
InStream_get_filename(InStream *self) { return self->filename; }

static void
S_refill(InStream *self) 
{
    /* Determine the amount to request. */
    const i64_t sub_file_pos = SI_tell(self);
    const i64_t remaining    = self->len - sub_file_pos;
    const i64_t amount       = remaining < IO_STREAM_BUF_SIZE 
                             ? remaining 
                             : IO_STREAM_BUF_SIZE;
    if (!remaining) {
        THROW(ERR, "Read past EOF of '%o' (offset: %i64 len: %i64)",
            self->filename, self->offset, self->len);
    }

    /* Make the request. */
    S_fill(self, amount);
}

void
InStream_refill(InStream *self)
{
    S_refill(self);
}

static void
S_fill(InStream *self, i64_t amount) 
{
    FileWindow *const window     = self->window;
    const i64_t virtual_file_pos = SI_tell(self);
    const i64_t real_file_pos    = virtual_file_pos + self->offset;
    const i64_t remaining        = self->len - virtual_file_pos;

    /* Throw an error if the requested amount would take us beyond EOF. */
    if (amount > remaining) {
        THROW(ERR,  "Read past EOF of %o (pos: %u64 len: %u64 request: %u64)",
            self->filename, virtual_file_pos, self->len, amount);
    }

    /* Make the request. */
    if (FH_Window(self->file_handle, window, real_file_pos, amount) ) {
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
        RETHROW(INCREF(Err_get_error()));
    }
}

void
InStream_fill(InStream *self, i64_t amount)
{
    S_fill(self, amount);
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
        FH_Release_Window(self->file_handle, window);
        self->buf   = NULL;
        self->limit = NULL;
        FileWindow_Set_Offset(window, self->offset + target);
    }
}

static INLINE i64_t
SI_tell(InStream *self)
{
    FileWindow *const window = self->window;
    i64_t pos_in_buf = PTR2I64(self->buf) - PTR2I64(window->buf);
    return pos_in_buf + window->offset - self->offset;
}

i64_t
InStream_tell(InStream *self) 
{
    return SI_tell(self);
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

    /* It's common for client code to overestimate how much is needed, because
     * the request has to figure in worst-case for compressed data.  However,
     * if we can still serve them everything they request (e.g. they ask for 5
     * bytes, they really need 1 byte, and there's 1k in the buffer), we can
     * skip the following refill block. */
    if ((i64_t)request > bytes_in_buf) {
        const i64_t remaining_in_file = self->len - SI_tell(self);
        i64_t amount = request;

        /* Try to bump up small requests. */
        if (amount < IO_STREAM_BUF_SIZE) { amount = IO_STREAM_BUF_SIZE; }

        /* Don't read past EOF. */
        if (remaining_in_file < amount) { amount = remaining_in_file; }

        /* Only fill if the recalculated, possibly smaller request exceeds the
         * amount available in the buffer. */
        if (amount > bytes_in_buf) { 
            S_fill(self, amount); 
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
            S_refill(self);
            memcpy(buf, self->buf, len);
            self->buf += len;
        }
        else {
            /* Too big to handle via the buffer, so resort to a brute-force
             * read. */
            const i64_t sub_file_pos  = SI_tell(self);
            const i64_t real_file_pos = sub_file_pos + self->offset;
            bool_t success 
                = FH_Read(self->file_handle, buf, real_file_pos, len);
            if (!success) {
                RETHROW(INCREF(Err_get_error()));
            }
            InStream_seek(self, sub_file_pos + len);
        }
    }
}

i8_t
InStream_read_i8(InStream *self)
{
    return (i8_t)SI_read_u8(self);
}

static INLINE u8_t
SI_read_u8(InStream *self)
{
    if (self->buf >= self->limit) { S_refill(self); }
    return (u8_t)*self->buf++;
}

u8_t
InStream_read_u8(InStream *self)
{
    return SI_read_u8(self);
}

static INLINE u32_t
SI_read_u32(InStream *self) 
{
    u32_t retval;
    SI_read_bytes(self, (char*)&retval, 4);
#ifdef LITTLE_END 
    retval = NumUtil_decode_bigend_u32((char*)&retval);
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
    retval = NumUtil_decode_bigend_u64((char*)&retval);
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
    union { float f; u32_t u32; } duo;
    SI_read_bytes(self, (char*)&duo, sizeof(float));
#ifdef LITTLE_END 
    duo.u32 = NumUtil_decode_bigend_u32(&duo.u32);
#endif
    return duo.f;
}

double
InStream_read_f64(InStream *self)
{
    union { double d; u64_t u64; } duo;
    SI_read_bytes(self, (char*)&duo, sizeof(double));
#ifdef LITTLE_END 
    duo.u64 = NumUtil_decode_bigend_u64(&duo.u64);
#endif
    return duo.d;
}

u32_t 
InStream_read_c32(InStream *self) 
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
InStream_read_c64(InStream *self) 
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
InStream_read_raw_c64(InStream *self, char *buf) 
{
    u8_t *dest = (u8_t*)buf;
    do {
        *dest = SI_read_u8(self);
    } while ((*dest++ & 0x80) != 0);
    return dest - (u8_t*)buf;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

