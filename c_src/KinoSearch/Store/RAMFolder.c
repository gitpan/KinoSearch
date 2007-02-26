#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_RAMFOLDER_VTABLE
#include "KinoSearch/Store/RAMFolder.r"

#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Store/RAMFileDes.r"

RAMFolder*
RAMFolder_new(const ByteBuf *path) 
{
    CREATE(self, RAMFolder, RAMFOLDER);

    /* init */
    self->ram_files = Hash_new(16);

    /* copy */
    if (path == NULL) {
        self->path = BB_new_str("", 0);
    }
    else {
        /* copy path, strip trailing slash or equivalent */
        self->path = BB_CLONE(path);
        if (self->path->len && (strcmp(BBEND(self->path) - 1, DIR_SEP) == 0))
            self->path->len -= 1;
    }

    return self;
}

void
RAMFolder_destroy(RAMFolder *self)
{
    REFCOUNT_DEC(self->path);
    REFCOUNT_DEC(self->ram_files);
    free(self);
}

OutStream*
RAMFolder_open_outstream(RAMFolder *self, const ByteBuf *filename)
{
    RAMFileDes *file_des = RAMFileDes_new(filename->ptr);
    Hash_Store_BB(self->ram_files, filename, (Obj*)file_des);
    REFCOUNT_DEC(file_des);
    return OutStream_new((FileDes*)file_des);
}

InStream*
RAMFolder_open_instream(RAMFolder *self, const ByteBuf *filename)
{
    RAMFileDes *file_des 
        = (RAMFileDes*)Hash_Fetch_BB(self->ram_files, filename);
    if (file_des == NULL) {
        CONFESS("File '%s' not loaded into RAM", filename->ptr);
    }
    return InStream_new((FileDes*)file_des);
}

VArray*
RAMFolder_list(RAMFolder *self)
{
    Hash *ram_files = self->ram_files;
    VArray *file_list = VA_new(0);
    ByteBuf *key;
    Obj     *ignore;

    Hash_Iter_Init(ram_files);
    while (Hash_Iter_Next(ram_files, &key, &ignore)) {
        ByteBuf *filename_copy = BB_CLONE(key);
        VA_Push(file_list, (Obj*)filename_copy);
        REFCOUNT_DEC(filename_copy);
    }

    return file_list;
}

bool_t
RAMFolder_file_exists(RAMFolder *self, const ByteBuf *filename)
{
    if (Hash_Fetch_BB(self->ram_files, filename) != NULL) {
        return true;
    }
    else {
        return false;
    }
}

void
RAMFolder_rename_file(RAMFolder *self, const ByteBuf* from, const ByteBuf *to)
{
    RAMFileDes *file_des = (RAMFileDes*)Hash_Fetch_BB(self->ram_files, from);

    if (file_des == NULL) {
        CONFESS("File '%s' not loaded into RAM", from->ptr);
    }

    Hash_Store_BB(self->ram_files, to, (Obj*)file_des);
    Hash_Delete_BB(self->ram_files, from);
}

void
RAMFolder_delete_file(RAMFolder *self, const ByteBuf *filename)
{
    bool_t success = Hash_Delete_BB(self->ram_files, filename);
    if (!success) {
        CONFESS("File '%s' not loaded into RAM", filename->ptr);
    }
}

ByteBuf*
RAMFolder_slurp_file(RAMFolder *self, const ByteBuf *filename)
{
    RAMFileDes *file_des = (RAMFileDes*)Hash_Fetch_BB(self->ram_files, filename);
    if (file_des == NULL) {
        CONFESS("File '%s' not loaded into RAM", filename->ptr);
    }
    return RAMFileDes_Contents(file_des);
}

void
RAMFolder_close_f(RAMFolder *self)
{
    UNUSED_VAR(self);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

