#include "KinoSearch/Util/ToolSet.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>

#define KINO_WANT_FSFOLDER_VTABLE
#include "KinoSearch/Store/FSFolder.r"

#include "KinoSearch/Store/FSFileDes.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/OutStream.r"

static ByteBuf*
full_path(FSFolder *self, const ByteBuf *filename);

static OutStream*
do_open_outstream(FSFolder *self, const ByteBuf *filename);

FSFolder*
FSFolder_new(const ByteBuf *path) 
{
    CREATE(self, FSFolder, FSFOLDER);
    
    /* copy path, strip trailing slash or equivalent */
    self->path = BB_CLONE(path);
    if (strcmp(BBEND(self->path) - 1, DIR_SEP) == 0)
        self->path->len -= 1;

    return self;
}

void
FSFolder_destroy(FSFolder *self)
{
    REFCOUNT_DEC(self->path);
    free(self);
}

#ifdef O_LARGEFILE
static const int write_flags 
    = O_CREAT | O_WRONLY | O_NONBLOCK | O_EXCL | O_LARGEFILE; 
static const int read_flags = O_RDONLY | O_NONBLOCK | O_LARGEFILE; 
#else
static const int write_flags 
    = O_CREAT | O_WRONLY | O_NONBLOCK | O_EXCL;
static const int read_flags = O_RDONLY | O_NONBLOCK; 
#endif

OutStream*
FSFolder_open_outstream(FSFolder *self, const ByteBuf *filename)
{
    OutStream *outstream = do_open_outstream(self, filename);
    if (outstream == NULL) 
        CONFESS("Can't open '%s': %s", filename->ptr, strerror(errno));
    return outstream;
}

OutStream*
FSFolder_safe_open_outstream(FSFolder *self, const ByteBuf *filename)
{
    return do_open_outstream(self, filename);
}

static OutStream*
do_open_outstream(FSFolder *self, const ByteBuf *filename)
{
    ByteBuf *path        = full_path(self, filename);
    FSFileDes *file_des  = FSFileDes_new(path->ptr, write_flags, 0600, "ab");
    OutStream *outstream = file_des == NULL
        ? NULL
        : OutStream_new((FileDes*)file_des);

    /* leave 1 refcount in file_des's new owner, outstream */
    REFCOUNT_DEC(file_des);
    REFCOUNT_DEC(path);

    return outstream;
}

InStream*
FSFolder_open_instream(FSFolder *self, const ByteBuf *filename)
{
    InStream *instream = NULL;
    ByteBuf *path = full_path(self, filename);
    FSFileDes *file_des 
        = FSFileDes_new(path->ptr, read_flags, 0600, "rb");

    REFCOUNT_DEC(path);

    if (file_des == NULL)
        CONFESS("Can't open '%s': %s", filename->ptr, strerror(errno));
    else
        instream = InStream_new((FileDes*)file_des);

    /* leave 1 refcount in file_des's new owner, instream */
    REFCOUNT_DEC(file_des);

    return instream;
}

VArray*
FSFolder_list(FSFolder *self)
{
    DIR *dir = opendir(self->path->ptr);
    struct dirent *entry; 
    VArray *dirlist = VA_new(0);

    if (dir == NULL) {
        CONFESS("Couldn't opendir '%s'", self->path->ptr);
    }
    while ((entry = readdir(dir)) != NULL ) {
        size_t len = strlen(entry->d_name);
        if (   (len == 1 && strncmp(entry->d_name, ".", 1) == 0)
            || (len == 2 && strncmp(entry->d_name, "..", 2) == 0)
        ) {
            continue;
        }
        else {
            ByteBuf *bb = BB_new_str(entry->d_name, len);
            VA_Push(dirlist, (Obj*)bb);
            REFCOUNT_DEC(bb);
        }
    }

    closedir(dir);
    
    return dirlist;
}

bool_t
FSFolder_file_exists(FSFolder *self, const ByteBuf *filename)
{
    struct stat sb;
    ByteBuf *path = full_path(self, filename);
    bool_t retval = false;
    if (stat(path->ptr, &sb) != -1)
        retval = true;
    REFCOUNT_DEC(path);
    return retval;
}

void
FSFolder_rename_file(FSFolder *self, const ByteBuf* from, const ByteBuf *to)
{
    ByteBuf *from_path = full_path(self, from);
    ByteBuf *to_path   = full_path(self, to);
    if (rename(from_path->ptr, to_path->ptr) ) {
        CONFESS("rename from '%s' to '%s' failed: %s", from_path->ptr,
            to_path->ptr, strerror(errno));
    }
    REFCOUNT_DEC(from_path);
    REFCOUNT_DEC(to_path);
}

void
FSFolder_delete_file(FSFolder *self, const ByteBuf *filename)
{
    ByteBuf *path = full_path(self, filename);
    if ( remove(path->ptr) ) {
        REFCOUNT_DEC(path);
        CONFESS("Couldn't remove file '%s': %s", filename->ptr,
            strerror(errno));
    }
    else {
        REFCOUNT_DEC(path);
    }
}

ByteBuf*
FSFolder_slurp_file(FSFolder *self, const ByteBuf *filename)
{
    ByteBuf *path = full_path(self, filename);
    FILE *f = fopen(path->ptr, "rb");
    ByteBuf *retval;
    size_t len;
    int amount_read;

    if (f == NULL) {
        REFCOUNT_DEC(path);
        CONFESS("Couldn't open file '%s': %s", filename->ptr, strerror(errno));
    }

    /* find length of file, allocate space */
    fseeko64(f, 0, SEEK_END);
    len = ftello64(f);
    fseeko64(f, 0, SEEK_SET);
    retval = BB_new(len);

    /* read and verify */
    amount_read = fread(retval->ptr, sizeof(char), len, f);
    if (amount_read < 0 || (size_t)amount_read != len) {
        REFCOUNT_DEC(path);
        REFCOUNT_DEC(retval);
        CONFESS("Expected %d bytes reading %s, got %d", (int)len,
            filename->ptr, amount_read);
    }
    retval->len = len;

    /* clean up */
    if (fclose(f)) {
        REFCOUNT_DEC(path);
        REFCOUNT_DEC(retval);
        CONFESS("Couldn't fclose file '%s': %s", filename->ptr, 
            strerror(errno));
    }
    REFCOUNT_DEC(path);

    return retval;
}

void
FSFolder_close_f(FSFolder *self)
{
    UNUSED_VAR(self);
}

static ByteBuf*
full_path(FSFolder *self, const ByteBuf *filename)
{
    ByteBuf *path = BB_new(200);
    BB_Cat_BB(path, self->path);
    BB_Cat_Str(path, DIR_SEP, sizeof(DIR_SEP) - 1);
    BB_Cat_BB(path, filename);
    return path;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

