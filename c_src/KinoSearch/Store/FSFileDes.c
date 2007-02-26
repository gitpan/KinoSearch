#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>

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
FSFileDes_new(const char *path, const char *mode) 
{
    CREATE(self, FSFileDes, FSFILEDES);

    /* init */
    self->pos          = 0;
    self->stream_count = 0;

    /* assign */
    self->path     = strdup(path);
    self->mode     = strdup(mode);

    /* open */
    self->fhandle = fopen(path, mode);
    if (self->fhandle == NULL) {
        CONFESS("Failed to open '%s': %s", path, strerror(errno));
    }

    /* track number of live FileDes released into the wild */
    FileDes_global_count++;

    return self;
}

void
FSFileDes_destroy(FSFileDes *self) 
{
    if (self->fhandle != NULL) {
        FileDes_FDClose(self);
    }

    free(self->path);
    free(self->mode);

    /* decrement count of FileDes structs in existence */
    FileDes_global_count--;

    free(self);
}

void
FSFileDes_fdseek(FSFileDes *self, u64_t target)
{
    CHECK_IO_OP( fseeko64(self->fhandle, target, SEEK_SET) );
    self->pos = target;
}

void
FSFileDes_fdread(FSFileDes *self, char *dest, u32_t dest_offset, u32_t len)
{
    int check_val = fread(dest + dest_offset, sizeof(char), len,
        self->fhandle);
    if (check_val < 0 || (u32_t)check_val != len) 
        CONFESS("Tried to read %d bytes, got %d: %s", 
            (int)len, check_val, strerror(errno));

    self->pos += len;
}

void
FSFileDes_fdwrite(FSFileDes *self, char* buf, u32_t len) 
{
    size_t check_val = fwrite(buf, sizeof(char), len, self->fhandle);
    if (check_val != len) {
        CONFESS("Attempted to write %lu bytes, but wrote %lu",
            (unsigned long)len, (unsigned long)check_val);
    }

    CHECK_IO_OP( fflush(self->fhandle) ); /* TODO -- kill this? */

    self->pos += len;
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

void
FSFileDes_fdclose(FSFileDes *self)
{
    if (self->fhandle != NULL) {
        if (fclose(self->fhandle)) {
            CONFESS("Failed to close file '%s': %s", self->path,
                strerror(errno));
        }
        self->fhandle = NULL;
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

