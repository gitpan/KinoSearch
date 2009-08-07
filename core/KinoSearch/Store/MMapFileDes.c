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
static char* 
S_win_error()
{
    size_t buf_size = 256;
    char *buf = MALLOCATE(buf_size, char);
    size_t message_len = FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, 
        NULL,       /* message source table */
        GetLastError(),
        0,          /* language id */
        buf,
        buf_size,
        NULL        /* empty va_list */
    );
    if (message_len == 0) {
        char unknown[] = "Unknown error";
        size_t len = sizeof(unknown);
        strncpy(buf, unknown, len);
    }
    else if (message_len > 1) {
        /* Kill stupid newline. */
        buf[message_len - 2] = '\0';
    }
    return buf;
}
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
    MMapFileDes *self = (MMapFileDes*)VTable_Make_Obj(MMAPFILEDES);
    return MMapFileDes_init(self, path);
}

MMapFileDes*
MMapFileDes_init(MMapFileDes *self, const CharBuf *path) 
{
    if (!path) THROW(ERR, "Missing required param 'path'");
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

#ifdef CHY_HAS_WINDOWS_H

bool_t
MMapFileDes_read(MMapFileDes *self, char *dest, u64_t offset, u32_t len)
{
    BOOL check_val;
    LARGE_INTEGER offs;
    DWORD got;
    
    /* Seek. */
    offs.QuadPart = offset;
    check_val = SetFilePointerEx(
        self->win_fhandle, offs, NULL, FILE_BEGIN);
    if (!check_val) {
        char *win_error = S_win_error();
        if (!self->mess) { self->mess = CB_new(256); }
        CB_catf(self->mess, "SetFilePointerEx to %u64 on %o failed: %s", 
            offset, self->path, win_error);
        FREEMEM(win_error);
        return false;
    }

    /* Read. */
    check_val = ReadFile(self->win_fhandle, dest, len, &got, NULL);
    if (!check_val) {
        char *win_error = S_win_error();
        if (!self->mess) { self->mess = CB_new(256); }
        CB_catf(self->mess, "Failed to read %u32 bytes: %s",
            len, win_error);
        FREEMEM(win_error);
        return false;
    }

    return true;
}

#else /* not WINDOWS_H */

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

#endif /* CHY_HAS_WINDOWS_H */

#endif /* IS_64_BIT vs. 32-bit */

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
        THROW(ERR, "lseek on %o failed: %s", self->path, strerror(errno));
    }
    else {
        i64_t check_val = lseek(self->fd, 0, SEEK_SET);
        if (check_val == -1) {
            THROW(ERR, "lseek on %o failed: %s", self->path, strerror(errno));
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
            THROW(ERR, "mmap of offset %i64 and length %i64 (page size %i64) "
                "against '%o' failed: %s", offset, len, self->page_size,
                self->path, strerror(errno));
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

/********************************* WINDOWS **********************************/

#elif defined(CHY_HAS_WINDOWS_H)

static INLINE bool_t 
SI_do_init(MMapFileDes *self)
{
    LARGE_INTEGER large_int;
    char *filepath = (char*)CB_Get_Ptr8(self->path);
    SYSTEM_INFO sys_info;

    /* Open. */
    self->win_fhandle = CreateFile(
        filepath,
        GENERIC_READ,
        FILE_SHARE_READ,
        NULL,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_READONLY,
        NULL
    );
    if (self->win_fhandle == INVALID_HANDLE_VALUE) {
        return false;
    }

    /* Derive len. */
    GetFileSizeEx(self->win_fhandle, &large_int);
    self->len = large_int.QuadPart;

    /* Init. */
    self->buf = NULL;
    if (self->len) {
        self->win_maphandle = CreateFileMapping(self->win_fhandle, NULL,
            PAGE_READONLY, 0, 0, NULL);
        if (self->win_maphandle == NULL) {
            char *win_error = S_win_error();
            CharBuf *mess = MAKE_MESS("CreateFileMapping for %o failed: %s", 
                self->path, win_error);
            FREEMEM(win_error);
            Err_throw_mess(ERR, mess);
        }
    }

    /* Get system page size. */
    GetSystemInfo(&sys_info);
    self->page_size = sys_info.dwAllocationGranularity;
    
    return true;
}

static INLINE void*
SI_map(MMapFileDes *self, i64_t offset, i64_t len)
{
    void *buf = NULL;

    if (len) {
        u64_t offs = (u64_t)offset;
        DWORD file_offset_hi = offs >> 32;
        DWORD file_offset_lo = offs & 0xFFFFFFFF;
        size_t amount = (size_t)len;
        buf = MapViewOfFile(
            self->win_maphandle, 
            FILE_MAP_READ, 
            file_offset_hi,
            file_offset_lo,
            amount
        );
        if (buf == NULL) {
            char *win_error = S_win_error();
            CharBuf *mess = MAKE_MESS("MapViewOfFile for %o failed: %s", 
                self->path, win_error);
            FREEMEM(win_error);
            Err_throw_mess(ERR, mess);
        }
    }

    return buf;
}

static INLINE bool_t
SI_unmap(MMapFileDes *self, char *buf, i64_t len)
{
    if (buf != NULL) {
        if (!UnmapViewOfFile(buf)) {
            char *win_error = S_win_error();
            if (!self->mess) self->mess = CB_new(256);
            CB_catf(self->mess, "Failed to unmap '%o': %s", self->path,
                win_error);
            FREEMEM(win_error);
            return false;
        }
    }

    return true;
}

static INLINE bool_t 
SI_close_handles(MMapFileDes *self)
{
    if (self->win_maphandle) {
        if (!CloseHandle(self->win_maphandle)) {
            char *win_error = S_win_error();
            if (!self->mess) self->mess = CB_new(30);
            CB_catf(self->mess, "Failed to close file mapping handle: %s", 
                win_error);
            FREEMEM(win_error);
            return false;
        }
        self->win_maphandle = NULL;
    }

    if (self->win_fhandle) {
        if (!CloseHandle(self->win_fhandle)) {
            char *win_error = S_win_error();
            if (!self->mess) self->mess = CB_new(30);
            CB_catf(self->mess, "Failed to close file handle: %s", win_error);
            FREEMEM(win_error);
            return false;
        }
        self->win_fhandle = NULL;
    }

    return true;
}

/********************************** OTHERS **********************************/

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

