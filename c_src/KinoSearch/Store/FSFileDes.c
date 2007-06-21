#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>
#include <fcntl.h>

#define KINO_WANT_FSFILEDES_VTABLE
#include "KinoSearch/Store/FSFileDes.r"


#define CHECK_IO_OP(x) \
    do { \
        int check_val = (x); \
        if (check_val == -1) { \
            CONFESS("File operation failed: %s", strerror(errno)); \
        } \
    } while (0)
    
FSFileDes*
FSFileDes_new(const char *path, int oflags, int fdmode, const char *fmode) 
{
    int fd;
    CREATE(self, FSFileDes, FSFILEDES);

    /* open */
    fd = open(path, oflags, fdmode);
    if (fd == -1) {
        free(self);
        return NULL;
    }
    self->fhandle = fdopen(fd, fmode);
    if (self->fhandle == NULL) {
        free(self);
        return NULL;
    }
    if (strcmp("wb+", fmode) == 0) {
        setvbuf(self->fhandle, NULL, _IONBF, 0);
    }

    /* init */
    self->pos          = 0;
    self->stream_count = 0;

    /* assign */
    self->path     = strdup(path);

    /* track number of live FileDes released into the wild */
    FileDes_object_count++;
    FileDes_open_count++;

    return self;
}

void
FSFileDes_destroy(FSFileDes *self) 
{
    if (self->fhandle != NULL) {
        FileDes_FDClose(self);
    }

    free(self->path);

    /* decrement count of FileDes structs in existence */
    FileDes_object_count--;

    free(self);
}

bool_t
FSFileDes_fdseek(FSFileDes *self, u64_t target)
{
    CHECK_IO_OP( fseeko64(self->fhandle, target, SEEK_SET) );
    self->pos = target;
    return true;
}

bool_t
FSFileDes_fdread(FSFileDes *self, char *dest, u32_t dest_offset, u32_t len)
{
    int check_val = fread(dest + dest_offset, sizeof(char), len,
        self->fhandle);
    if (check_val < 0 || (u32_t)check_val != len) {
        Carp_set_kerror("Tried to read %lu bytes, got %d: %s", 
            (unsigned long)len, check_val, strerror(errno));
        return false;
    }

    self->pos += len;

    return true;
}

bool_t
FSFileDes_fdwrite(FSFileDes *self, const char* buf, u32_t len) 
{
    size_t check_val;
    
    if (len == 0)
        return true;

    check_val = fwrite(buf, sizeof(char), len, self->fhandle);
    if (check_val != len) {
        Carp_set_kerror("Attempted to write %lu bytes, but wrote %lu",
            (unsigned long)len, (unsigned long)check_val);
        return false;
    }

    self->pos += len;

    return true;
}


u64_t
FSFileDes_fdlength(FSFileDes *self)
{
    /* save bookmark, seek to end, note length, return to bookmark */
    u64_t len;
    u64_t bookmark = ftello64(self->fhandle);
    CHECK_IO_OP(bookmark);
    CHECK_IO_OP( fseeko64(self->fhandle, 0, SEEK_END) );
    len = ftello64(self->fhandle);
    CHECK_IO_OP(len);
    CHECK_IO_OP( fseeko64(self->fhandle, bookmark, SEEK_SET) );
    return len;
}

bool_t
FSFileDes_fdclose(FSFileDes *self)
{
    if (self->fhandle != NULL) {
        if (fclose(self->fhandle)) {
            Carp_set_kerror("Failed to close file: %s", strerror(errno));
            return false;
        }
        FileDes_open_count--;
        self->fhandle = NULL;
    }

    return true;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

