#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Store/RAMFolder.h"
#include "KinoSearch/Store/FSFolder.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Store/RAMFileDes.h"

/* Read in an FSFolder at self's path. */
static void
S_read_fsfolder(RAMFolder *self);

RAMFolder*
RAMFolder_new(const CharBuf *path) 
{
    RAMFolder *self = (RAMFolder*)VTable_Make_Obj(&RAMFOLDER);
    return RAMFolder_init(self, path);
}

RAMFolder*
RAMFolder_init(RAMFolder *self, const CharBuf *path)
{
    Folder_init((Folder*)self, path);
    self->elems = Hash_new(16);
    if (CB_Get_Size(self->path) != 0) S_read_fsfolder(self);
    return self;
}

void
RAMFolder_destroy(RAMFolder *self)
{
    DECREF(self->elems);
    SUPER_DESTROY(self, RAMFOLDER);
}

void
RAMFolder_initialize(RAMFolder *self)
{
    UNUSED_VAR(self);
}

bool_t
RAMFolder_check(RAMFolder *self)
{
    UNUSED_VAR(self);
    return true;
}

static void
S_read_fsfolder(RAMFolder *self) 
{
    u32_t i, max;
    /* Open an FSFolder for reading. */
    FSFolder *source_folder = FSFolder_new(self->path);
    VArray *files = FSFolder_List(source_folder);

    /* Copy every file in the FSFolder into RAM. */
    for (i = 0, max = VA_Get_Size(files); i < max; i++) {
        CharBuf *filepath = (CharBuf*)VA_Fetch(files, i);
        InStream *source_stream 
            = FSFolder_Open_In(source_folder, filepath);
        OutStream *outstream = RAMFolder_Open_Out(self, filepath);
        if (!source_stream) { THROW("Can't open %o", filepath); }
        if (!outstream)     { THROW("Can't open %o", filepath); }
        OutStream_Absorb(outstream, source_stream);
        OutStream_Close(outstream);
        InStream_Close(source_stream);
        DECREF(outstream);
        DECREF(source_stream);
    }

    DECREF(files);
    FSFolder_Close(source_folder);
    DECREF(source_folder);
}

void
RAMFolder_mkdir(RAMFolder *self, const CharBuf *path)
{
    Hash_Store(self->elems, (Obj*)path, (Obj*)RAMFileDes_new(path));
}

RAMFileDes*
RAMFolder_ram_file(RAMFolder *self, const CharBuf *filepath)
{
    RAMFileDes *ram_file 
        = (RAMFileDes*)Hash_Fetch(self->elems, (Obj*)filepath);
    if (ram_file == NULL)
        THROW( "File '%o' not loaded into RAM", filepath);
    return ram_file;
}

OutStream*
RAMFolder_open_out(RAMFolder *self, const CharBuf *filepath)
{
    if (Hash_Fetch(self->elems, (Obj*)filepath)) {
        return NULL;
    }
    else {
        RAMFileDes *file_des = RAMFileDes_new(filepath);
        Hash_Store(self->elems, (Obj*)filepath, (Obj*)file_des);
        return OutStream_new((FileDes*)file_des);
    }
}

FileDes*
RAMFolder_open_filedes(RAMFolder *self, const CharBuf *filepath)
{
    RAMFileDes *file_des 
        = (RAMFileDes*)Hash_Fetch(self->elems, (Obj*)filepath);
    return file_des ? (FileDes*)INCREF(file_des) : NULL;
}

VArray*
RAMFolder_list(RAMFolder *self)
{
    Hash *elems = self->elems;
    VArray *file_list = VA_new(0);
    CharBuf *key;
    Obj     *ignore;

    Hash_Iter_Init(elems);
    while (Hash_Iter_Next(elems, (Obj**)&key, &ignore)) {
        VA_Push(file_list, (Obj*)CB_Clone(key));
    }

    return file_list;
}

bool_t
RAMFolder_exists(RAMFolder *self, const CharBuf *filepath)
{
    if (Hash_Fetch(self->elems, (Obj*)filepath) != NULL) {
        return true;
    }
    else {
        return false;
    }
}

void
RAMFolder_rename(RAMFolder *self, const CharBuf* from, const CharBuf *to)
{
    RAMFileDes *file_des = (RAMFileDes*)Hash_Delete(self->elems, (Obj*)from);

    if (file_des == NULL) {
        THROW("File '%o' not loaded into RAM", from);
    }

    Hash_Store(self->elems, (Obj*)to, (Obj*)file_des);
    FileDes_Set_Path(file_des, to);
}

bool_t
RAMFolder_delete(RAMFolder *self, const CharBuf *filepath)
{
    RAMFileDes *file_des 
        = (RAMFileDes*)Hash_Delete(self->elems, (Obj*)filepath);
    if (file_des) { RAMFileDes_Dec_RefCount(file_des); }
    return !!file_des;
}

void
RAMFolder_close(RAMFolder *self)
{
    UNUSED_VAR(self);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

