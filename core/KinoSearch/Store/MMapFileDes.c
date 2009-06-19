#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdarg.h>

#ifdef CHY_HAS_SYS_MMAN_H
#include <sys/mman.h>
#endif

#ifdef CHY_HAS_UNISTD_H 
#include <unistd.h>
#endif

#ifdef CHY_HAS_WINDOWS_H 
#include <windows.h>
#include <io.h>
#endif

#include "KinoSearch/Store/MMapFileDes.h"
#include "KinoSearch/Store/FileWindow.h"

#define IS_64_BIT (SIZEOF_PTR == 8 ? true : false)

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

static INLINE void*
SI_map(MMapFileDes *self, i64_t offset, i64_t len);

static INLINE bool_t
SI_unmap(MMapFileDes *self, char *ptr, i64_t len);

static INLINE bool_t 
SI_do_init(MMapFileDes *self);

static INLINE bool_t 
SI_close_handles(MMapFileDes *self);

MMapFileDes*
MMapFileDes_new(const CharBuf *path) 
{
    MMapFileDes *self = (MMapFileDes*)VTable_Make_Obj(&MMAPFILEDES);
    return MMapFileDes_init(self, path);
}

MMapFileDes*
MMapFileDes_init(MMapFileDes *self, const CharBuf *path) 
{
    if (!path) THROW("Missing required param 'path'");
    FileDes_init((FileDes*)self, path);

    /* Open file or return NULL. */
    if ( !SI_do_init(self) ) {
        FREE_OBJ(self);
        return NULL;
    }

    /* On 64-bit systems, map the whole file up-front. */
    if (IS_64_BIT && self->len) {
        self->buf = SI_map(self, 0, self->len);
    }

    return self;
}

bool_t
MMapFileDes_close(MMapFileDes *self)
{
    /* On 64-bit systems, cancel the whole-file mapping. */
    if (IS_64_BIT) {
        if ( !SI_unmap(self, self->buf, self->len) ) { return false; }
        self->buf = NULL;
    }

    /* Close filehandles. */
    if ( !SI_close_handles(self) ) { return false; }

    return true;
}

u64_t
MMapFileDes_length(MMapFileDes *self)
{
    return self->len;
}

/********************************* 64-bit *********************************/

#if IS_64_BIT

bool_t
MMapFileDes_window(MMapFileDes *self, FileWindow *window, i64_t offset, 
                   i64_t len)
{
    if (offset + len > self->len) {
        if (!self->mess) self->mess = CB_new(50);
        CB_catf(self->mess,
            "Tried to read past EOF: offset %i64 + request %i64 > len %i64", 
            offset, len, self->len);
        return false;
    }
    else {
        window->buf    = self->buf + offset;
        window->offset = offset;
        window->len    = len;
        window->cap    = self->len;
        return true;
    }
}

bool_t
MMapFileDes_release_window(MMapFileDes *self, FileWindow *window)
{
    UNUSED_VAR(self);
    window->buf    = NULL;
    window->offset = 0;
    window->len    = 0;
    window->cap    = 0;
    return true;
}

bool_t
MMapFileDes_read(MMapFileDes *self, char *dest, u64_t offset, u32_t len)
{
    const i64_t new_pos = offset + len;
    if (new_pos > self->len) {
        if (!self->mess) self->mess = CB_new(50);
        CB_catf(self->mess,
            "Tried to read past EOF: offset %i64 + request %u32 > len %i64", 
            offset, len, self->len);
        return false;
    }
    memcpy(dest, self->buf + offset, len);
    return true;
}

/********************************* 32-bit *********************************/
#else

bool_t
MMapFileDes_window(MMapFileDes *self, FileWindow *window, i64_t offset, 
                   i64_t len)
{
    if (offset + len > self->len) {
        if (!self->mess) self->mess = CB_new(50);
        CB_catf(self->mess,
            "Tried to read past EOF: offset %i64 + request %i64 > len %i64", 
            offset, len, self->len);
        return false;
    }
    else {
        i64_t remainder = offset % self->page_size;

        /* Release the previously mmap'd region, if any. */
        MMapFileDes_release_window(self, window);

        /* Start map on a page boundary.  Ensure that the window is at least
         * wide enough to view all the data spec'd in the original request. */
        window->offset = offset - remainder;
        window->len    = len + remainder; 
        window->cap    = window->len;
        window->buf    = SI_map(self, window->offset, window->len);

        return true;
    }
}

bool_t
MMapFileDes_release_window(MMapFileDes *self, FileWindow *window)
{
    if ( !SI_unmap(self, window->buf, window->len) ) { return false; }
    window->buf    = NULL;
    window->offset = 0;
    window->len    = 0;
    window->cap    = 0;
    return true;
}

bool_t
MMapFileDes_read(MMapFileDes *self, char *dest, u64_t offset, u32_t len)
{
    /* Seek. */
    i64_t check_val = lseek(self->fd, (long)offset, SEEK_SET);
    if (check_val == -1) {
        if (!self->mess) { self->mess = CB_new(50); }
        CB_catf(self->mess, "lseek to %u64 on %o failed: %s", 
            offset, self->path, strerror(errno));
        return false;
    }

    /* Read. */
    check_val = read(self->fd, dest, len);
    if ((u32_t)check_val != len) {
        if (!self->mess) { self->mess = CB_new(50); }
        CB_catf(self->mess, "Tried to read %u32 bytes, got %i64",
            len, check_val);
        if (check_val == -1) {
            CB_catf(self->mess, ": %s", strerror(errno));
        }
        return false;
    }

    return true;
}

#endif /* IS_64_BIT */

/********************************* UNIXEN *********************************/

#ifdef CHY_HAS_SYS_MMAN_H

static INLINE bool_t 
SI_do_init(MMapFileDes *self)
{
    /* Open. */
    self->fd = open((char*)CB_Get_Ptr8(self->path), SI_read_flags(), 0666);
    if (self->fd == -1) {
        return false;
    }

    /* Derive len. */
    self->len = lseek(self->fd, 0, SEEK_END);
    if (self->len == -1) {
        THROW("lseek on %o failed: %s", self->path, strerror(errno));
    }
    else {
        i64_t check_val = lseek(self->fd, 0, SEEK_SET);
        if (check_val == -1) {
            THROW("lseek on %o failed: %s", self->path, strerror(errno));
        }
    }

    /* Get system page size. */
#if defined(_SC_PAGESIZE)
	self->page_size = sysconf(_SC_PAGESIZE);
#elif defined(_SC_PAGE_SIZE)
	self->page_size = sysconf(_SC_PAGE_SIZE);
#else
    #error "Can't determine system memory page size"
#endif
    
    return true;
}

static INLINE void*
SI_map(MMapFileDes *self, i64_t offset, i64_t len)
{
    void *buf = NULL;

    if (len) {
        buf = mmap(NULL, len, PROT_READ, MAP_SHARED, self->fd, offset);
        if (buf == (void*)-1) {
            THROW("mmap of '%o' failed: %s", self->path, strerror(errno));
        }
    }

    return buf;
}

static INLINE bool_t
SI_unmap(MMapFileDes *self, char *buf, i64_t len)
{
    if (buf != NULL) {
        if (munmap(buf, len)) {
            if (!self->mess) self->mess = CB_new(30);
            CB_catf(self->mess, "Failed to munmap '%o': %s", self->path, 
                strerror(errno));
            return false;
        }
    }

    return true;
}

static INLINE bool_t 
SI_close_handles(MMapFileDes *self)
{
    if (self->fd) {
        if (close(self->fd)) {
            if (!self->mess) self->mess = CB_new(30);
            CB_catf(self->mess, "Failed to close file: %s", 
                strerror(errno));
            return false;
        }
        self->fd  = 0;
    }

    return true;
}

/**************************** WINDOWS AND OTHERS ****************************/

/* Fall back to FSFileDes, but give the compiler stubs. */
#else 

static INLINE bool_t 
SI_do_init(MMapFileDes *self)
{
    UNUSED_VAR(self);
    UNREACHABLE_RETURN(bool_t);
}

static INLINE void*
SI_map(MMapFileDes *self, i64_t offset, i64_t len)
{
    UNUSED_VAR(self);
    UNUSED_VAR(offset);
    UNUSED_VAR(len);
    UNREACHABLE_RETURN(void*);
}

static INLINE bool_t
SI_unmap(MMapFileDes *self, char *buf, i64_t len)
{
    UNUSED_VAR(self);
    UNUSED_VAR(len);
    UNREACHABLE_RETURN(bool_t);
}

static INLINE bool_t 
SI_close_handles(MMapFileDes *self)
{
    UNUSED_VAR(self);
    UNREACHABLE_RETURN(bool_t);
}

#endif /* CHY_HAS_SYS_MMAN_H */

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

