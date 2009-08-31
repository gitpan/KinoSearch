#define C_KINO_FSFILEDES
#define C_KINO_FILEWINDOW
#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdarg.h>

#ifdef HAS_IO_H
#include <io.h>
#endif

#include "KinoSearch/Store/FSFileDes.h"
#include "KinoSearch/Store/FileWindow.h"

static INLINE int 
SI_write_flags()
{
    int flags = O_CREAT | O_WRONLY | O_EXCL;
#ifdef O_LARGEFILE
    flags |= O_LARGEFILE;
#endif
#ifdef _O_BINARY 
    flags |= _O_BINARY;
#endif
    return flags;
}

static INLINE int 
SI_read_flags()
{
    int flags = O_RDONLY;
#ifdef O_LARGEFILE
    flags |= O_LARGEFILE;
#endif
#ifdef _O_BINARY 
    flags |= _O_BINARY;
#endif
    return flags;
}

FSFileDes*
FSFileDes_new(const CharBuf *path, const char *mode) 
{
    int         fd;
    FILE       *fhandle;
    FSFileDes  *self = (FSFileDes*)VTable_Make_Obj(FSFILEDES);
    int         oflags = *mode == 'w' ? SI_write_flags() : SI_read_flags();
    const char *fmode  = *mode == 'w' ? "ab" : "rb";

    if (*mode != 'w' && *mode != 'r') {
        THROW(ERR, "invalid value for 'mode': %s", mode);
    }

    /* Open. */
    if (!path) { THROW(ERR, "Missing required param 'path'"); }
    fd = open((char*)CB_Get_Ptr8(path), oflags, 0666);
    if (fd == -1) { SUPER_DESTROY(self, FSFILEDES); return NULL; }
    fhandle = fdopen(fd, fmode);
    if (fhandle == NULL) { SUPER_DESTROY(self, FSFILEDES); return NULL; }
    if (*mode == 'w')    { setvbuf(fhandle, NULL, _IONBF, 0); }
    self->fhandle = fhandle;

    /* Init. */
    FileDes_init((FileDes*)self, path);

    return self;
}

bool_t
FSFileDes_window(FSFileDes *self, FileWindow *window, i64_t offset, i64_t len)
{
    if (window->cap < len) {
        window->cap = len < IO_STREAM_BUF_SIZE ? IO_STREAM_BUF_SIZE : len;
        window->buf = REALLOCATE(window->buf, (size_t)window->cap, char);
    }
    window->offset = offset;
    window->len    = len;
    return FSFileDes_read(self, window->buf, offset, (u32_t)len);
}

bool_t
FSFileDes_release_window(FSFileDes *self, FileWindow *window)
{
    UNUSED_VAR(self);
    FREEMEM(window->buf);
    window->buf = NULL;
    window->len = 0;
    window->cap = 0;
    return true;
}

bool_t
FSFileDes_read(FSFileDes *self, char *dest, u64_t offset, u32_t len)
{
    FILE *fhandle = self->fhandle;
    i64_t check_val;

    /* Seek. */
    check_val = fseeko64(fhandle, offset, SEEK_SET);
    if (check_val == -1) {
        if (!self->mess) self->mess = CB_new(40);
        CB_catf(self->mess, "fseeko64 failed: %s", strerror(errno));
        return false;
    }

    /* Read. */
    check_val = fread(dest, sizeof(char), len, fhandle);
    if ((u32_t)check_val != len) {
        if (!self->mess) self->mess = CB_new(50);
        if (feof(fhandle)) {
            CB_catf(self->mess, 
                "Tried to read past EOF (wanted %u32 bytes, got %i32)",
                len, (i32_t)check_val);
        }
        else { 
            CB_catf(self->mess, "Tried to read %u32 bytes, got %i32",
                len, (i32_t)check_val);
            if (ferror(fhandle)) {
                CB_catf(self->mess, ": %s", strerror(errno));
            }
        }
        return false;
    }

    return true;
}

bool_t
FSFileDes_write(FSFileDes *self, const void *buf, u32_t len) 
{
    FILE *fhandle = self->fhandle;
    size_t check_val;
    
    if (len == 0)
        return true;

    check_val = fwrite(buf, sizeof(char), len, fhandle);
    if (check_val != len) {
        if (!self->mess) self->mess = CB_new(50);
        CB_catf(self->mess, "Attempted to write %u32 bytes, but wrote %u64",
            len, (u64_t)check_val);
        return false;
    }

    return true;
}

#define CHECK_IO_OP(x) \
    do { \
        i64_t check_val = (x); \
        if (check_val == -1) { \
            THROW(ERR, "File operation failed: %s", strerror(errno)); \
        } \
    } while (0)

u64_t
FSFileDes_length(FSFileDes *self)
{
    /* Save bookmark, seek to end, note length, return to bookmark. */
    FILE *fhandle = self->fhandle;
    u64_t len;
    u64_t bookmark = ftello64(fhandle);
    CHECK_IO_OP(bookmark);
    CHECK_IO_OP( fseeko64(fhandle, 0, SEEK_END) );
    len = ftello64(fhandle);
    CHECK_IO_OP(len);
    CHECK_IO_OP( fseeko64(fhandle, bookmark, SEEK_SET) );
    return len;
}

bool_t
FSFileDes_close(FSFileDes *self)
{
    if (self->fhandle != NULL) {
        if (fclose((FILE*)self->fhandle)) {
            if (!self->mess) self->mess = CB_new(30);
            CB_catf(self->mess, "Failed to close file: %s", 
                strerror(errno));
            return false;
        }
        self->fhandle = NULL;
    }

    return true;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

