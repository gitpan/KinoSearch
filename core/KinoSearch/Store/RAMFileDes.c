#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>

#include "KinoSearch/Store/RAMFileDes.h"
#include "KinoSearch/Store/FileWindow.h"

RAMFileDes*
RAMFileDes_new(const CharBuf *path) 
{
    RAMFileDes *self = (RAMFileDes*)VTable_Make_Obj(RAMFILEDES);
    return RAMFileDes_init(self, path);
}

RAMFileDes*
RAMFileDes_init(RAMFileDes *self, const CharBuf *path) 
{
    FileDes_init((FileDes*)self, path);
    self->buffers      = VA_new(1);
    self->len          = 0;
    return self;
}

void
RAMFileDes_destroy(RAMFileDes *self) 
{
    DECREF(self->buffers);
    SUPER_DESTROY(self, RAMFILEDES);
}

bool_t
RAMFileDes_window(RAMFileDes *self, FileWindow *window, i64_t offset, 
                  i64_t len)
{
    if (window->cap < len) {
        window->cap = len < IO_STREAM_BUF_SIZE ? IO_STREAM_BUF_SIZE : len;
        window->buf = REALLOCATE(window->buf, (size_t)window->cap, char);
    }
    window->offset = offset;
    window->len    = len;
    return RAMFileDes_read(self, window->buf, offset, (u32_t)len);
}

bool_t
RAMFileDes_release_window(RAMFileDes *self, FileWindow *window)
{
    UNUSED_VAR(self);
    FREEMEM(window->buf);
    window->buf = NULL;
    window->len = 0;
    window->cap = 0;
    return true;
}

bool_t
RAMFileDes_read(RAMFileDes *self, char *dest, u64_t offset, u32_t len)
{
    VArray *const buffers = self->buffers;
    u32_t bytes_wanted = len;
    u32_t buf_num = (u32_t)(offset / IO_STREAM_BUF_SIZE);
    i64_t pos = offset;

    if (pos + len > (i64_t)self->len) {
        if (!self->mess) self->mess = CB_new(100);
        CB_catf(self->mess,
            "Attempt to read %u32 bytes starting at %u64 goes past EOF %u64",
            len, pos, self->len);
        return false;
    }

    while (bytes_wanted) {
        const u32_t source_offset = pos % IO_STREAM_BUF_SIZE;
        const u32_t bytes_in_buf = IO_STREAM_BUF_SIZE - source_offset;
        const u32_t bytes_to_copy = bytes_in_buf > bytes_wanted
            ? bytes_wanted
            : bytes_in_buf;
        ByteBuf *const buffer = (ByteBuf*)VA_Fetch(buffers, buf_num);
        char *const source = BB_Get_Buf(buffer) + source_offset; 

        memcpy(dest, source, bytes_to_copy);

        buf_num++;
        dest += bytes_to_copy;
        bytes_wanted -= bytes_to_copy;
        pos += bytes_to_copy;
    }

    return true;
} 

bool_t
RAMFileDes_write(RAMFileDes *self, const void *buf, u32_t len) 
{
    VArray *const buffers = self->buffers;
    const char *source = (const char*)buf;
    u32_t num_buffers = VA_Get_Size(buffers);
    u32_t bytes_left = len;
    u32_t dest_buf_num = (u32_t)(self->len / IO_STREAM_BUF_SIZE);
    
    while (bytes_left) {
        ByteBuf *buffer;
        char *dest;
        const u32_t dest_offset = self->len % IO_STREAM_BUF_SIZE;
        const u32_t room_in_dest_buf = IO_STREAM_BUF_SIZE - dest_offset;
        const u32_t bytes_to_copy = bytes_left > room_in_dest_buf 
            ? room_in_dest_buf 
            : bytes_left;

        if (dest_buf_num >= num_buffers) {
            buffer = BB_new(IO_STREAM_BUF_SIZE);
            VA_Push(buffers, (Obj*)buffer);
            num_buffers++;
        }
        else {
            buffer = (ByteBuf*)VA_Fetch(buffers, dest_buf_num);
        }
        
        dest = BB_Get_Buf(buffer) + dest_offset;
        memcpy(dest, source, bytes_to_copy * sizeof(char));
        if (dest_offset + bytes_to_copy > BB_Get_Size(buffer)) {
            BB_Set_Size(buffer, dest_offset + bytes_to_copy);
        }

        dest_buf_num++;
        source += bytes_to_copy;
        self->len += bytes_to_copy;
        bytes_left -= bytes_to_copy;
    }

    return true;
}

ByteBuf*
RAMFileDes_contents(RAMFileDes *self)
{
    ByteBuf *retval = NULL;

    if (self->len > I32_MAX) {
        THROW(ERR, "length for %o is %u64 -- too large", self->path, self->len);
    }
    else {
        VArray  *buffers    = self->buffers;
        u32_t    bytes_left = (u32_t)self->len;
        u32_t    i, max;

        retval  = BB_new((size_t)self->len);
        for (i = 0, max = VA_Get_Size(buffers); i < max; i++) {
            ByteBuf *const buffer = (ByteBuf*)VA_Fetch(buffers, i);
            if (bytes_left < BB_Get_Size(buffer)) {
                BB_Set_Size(buffer, bytes_left);
            }
            BB_Cat(retval, buffer);
            bytes_left -= BB_Get_Size(buffer);
            if (!bytes_left)
                break;
        }
    }

    return retval;
}

u64_t
RAMFileDes_length(RAMFileDes *self)
{
    return self->len;
}

bool_t
RAMFileDes_close(RAMFileDes *self)
{
    UNUSED_VAR(self);
    return true;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

