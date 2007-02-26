#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>

#define KINO_WANT_RAMFILEDES_VTABLE
#include "KinoSearch/Store/RAMFileDes.r"


RAMFileDes*
RAMFileDes_new(const char *path) 
{
    CREATE(self, RAMFileDes, RAMFILEDES);

    /* init */
    self->buffers      = VA_new(1);
    self->pos          = 0;
    self->stream_count = 0;
    self->len          = 0;
    self->mode         = strdup("");

    /* assign */
    self->path     = strdup(path);

    /* track number of live FileDes released into the wild */
    FileDes_global_count++;

    return self;
}

void
RAMFileDes_destroy(RAMFileDes *self) 
{
    REFCOUNT_DEC(self->buffers);
    free(self->path);
    free(self->mode);

    /* decrement count of FileDes structs in existence */
    FileDes_global_count--;

    free(self);
}

void
RAMFileDes_fdseek(RAMFileDes *self, u64_t target)
{
    if (target > self->len) {
        CONFESS("Attempt to seek past EOF: %d %d", (int)target,
            (int)self->len);
    }
    self->pos = target;
}

void
RAMFileDes_fdread(RAMFileDes *self, char *dest, u32_t dest_offset, u32_t len)
{
    VArray *const buffers = self->buffers;
    u32_t bytes_wanted = len;
    u32_t buf_num = self->pos / IO_STREAM_BUF_SIZE;

    if (self->pos + len > self->len) {
        CONFESS("Attempt to read %lu bytes starting at %lu goes past EOF %lu",
            (unsigned long)len, (unsigned long)self->pos, 
            (unsigned long)self->len);
    }

    dest += dest_offset;

    while (bytes_wanted) {
        const u32_t source_offset = self->pos % IO_STREAM_BUF_SIZE;
        const u32_t bytes_in_buf = IO_STREAM_BUF_SIZE - source_offset;
        const u32_t bytes_to_copy = bytes_in_buf > bytes_wanted
            ? bytes_wanted
            : bytes_in_buf;
        ByteBuf *const buffer = (ByteBuf*)VA_Fetch(buffers, buf_num);
        char *const source = buffer->ptr + source_offset; 

        memcpy(dest, source, bytes_to_copy);

        buf_num++;
        dest += bytes_to_copy;
        bytes_wanted -= bytes_to_copy;
        self->pos += bytes_to_copy;
    }
} 

void
RAMFileDes_fdwrite(RAMFileDes *self, char* source, u32_t len) 
{
    VArray *const buffers = self->buffers;
    u32_t bytes_left = len;
    u32_t dest_buf_num = self->pos / IO_STREAM_BUF_SIZE;
    
    while (bytes_left) {
        ByteBuf *buffer;
        char *dest;
        const u32_t dest_offset = self->pos % IO_STREAM_BUF_SIZE;
        const u32_t room_in_dest_buf = IO_STREAM_BUF_SIZE - dest_offset;
        const u32_t bytes_to_copy = bytes_left > room_in_dest_buf 
            ? room_in_dest_buf 
            : bytes_left;

        if (dest_buf_num >= buffers->size) {
            buffer = BB_new(IO_STREAM_BUF_SIZE);
            VA_Push(buffers, (Obj*)buffer);
            REFCOUNT_DEC(buffer);
        }
        else {
            buffer = (ByteBuf*)VA_Fetch(buffers, dest_buf_num);
        }
        
        dest = buffer->ptr + dest_offset;
        memcpy(dest, source, bytes_to_copy * sizeof(char));
        if (dest_offset + bytes_to_copy > buffer->len)
            buffer->len = dest_offset + bytes_to_copy;

        dest_buf_num++;
        source += bytes_to_copy;
        self->pos += bytes_to_copy;
        bytes_left -= bytes_to_copy;
    }

    if (self->pos > self->len) {
        self->len = self->pos;
    }
}

ByteBuf*
RAMFileDes_contents(RAMFileDes *self)
{
    ByteBuf *retval = BB_new(self->len);
    VArray *buffers = self->buffers;
    kino_u32_t i;
    kino_u32_t bytes_left = self->len;
    

    for (i = 0; i < buffers->size; i++) {
        ByteBuf *const buffer = (ByteBuf*)VA_Fetch(buffers, i);
        if (bytes_left < buffer->len)
            buffer->len = bytes_left;
        BB_Cat_BB(retval, buffer);
        bytes_left -= buffer->len;
        if (!bytes_left)
            break;
    }

    return retval;
}

u64_t
RAMFileDes_fdlength(RAMFileDes *self)
{
    return self->len;
}

void
RAMFileDes_fdclose(RAMFileDes *self)
{
    UNUSED_VAR(self);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

