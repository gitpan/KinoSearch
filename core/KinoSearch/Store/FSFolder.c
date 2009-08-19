#include "KinoSearch/Util/ToolSet.h"

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/stat.h>

#include "KinoSearch/Store/FSFolder.h"
#include "KinoSearch/Store/CompoundFileReader.h"
#include "KinoSearch/Store/CompoundFileWriter.h"
#include "KinoSearch/Store/FSFileDes.h"
#include "KinoSearch/Store/MMapFileDes.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/Compat/DirManip.h"

static CharBuf*
S_full_path(FSFolder *self, const CharBuf *filepath);

/* If the file might belong in a virtual file and the appropriate compound
 * files can be found, return a CompoundFileReader.
 */
static CompoundFileReader*
S_get_cf_reader(FSFolder *self, const CharBuf *filepath);

/* Extract a segment name from a filepath. */
static ZombieCharBuf 
S_derive_seg_name(const CharBuf *filepath);

FSFolder*
FSFolder_new(const CharBuf *path) 
{
    FSFolder *self = (FSFolder*)VTable_Make_Obj(FSFOLDER);
    return FSFolder_init(self, path);
}

FSFolder*
FSFolder_init(FSFolder *self, const CharBuf *path)
{
    Folder_init((Folder*)self, path);
    self->cf_readers = Hash_new(0);
    return self;
}

void
FSFolder_destroy(FSFolder *self)
{
    DECREF(self->cf_readers);
    SUPER_DESTROY(self, FSFOLDER);
}

void
FSFolder_initialize(FSFolder *self)
{
    if (!DirManip_dir_ok(self->path)) {
        DirManip_create_dir(self->path);
    }
}

bool_t
FSFolder_check(FSFolder *self)
{
    return DirManip_dir_ok(self->path);
}

OutStream*
FSFolder_open_out(FSFolder *self, const CharBuf *filepath)
{
    CharBuf   *fullpath  = S_full_path(self, filepath);
    FSFileDes *file_des  = FSFileDes_new(fullpath, "w");
    OutStream *outstream = file_des == NULL
        ? NULL
        : OutStream_new((FileDes*)file_des);

    /* Leave 1 refcount in file_des's new owner, outstream. */
    DECREF(file_des);
    DECREF(fullpath);

    return outstream;
}

InStream*
FSFolder_open_in(FSFolder *self, const CharBuf *filepath)
{
    InStream           *instream  = NULL;
    ZombieCharBuf       seg_name  = S_derive_seg_name(filepath);
    CompoundFileReader *cf_reader = (CompoundFileReader*)Hash_Fetch(
        self->cf_readers, (Obj*)&seg_name);

    /* If we already have a CompoundFileReader loaded, try that first. */
    if (   cf_reader != NULL
        && cf_reader != (CompoundFileReader*)UNDEF
        && CFReader_Exists(cf_reader, filepath)
    ) {
        instream = CFReader_Open_In(cf_reader, filepath);
    }

    /* No virtual file?  Maybe there's a real file. */
    if (instream == NULL && FSFolder_Real_Exists(self, filepath)) {
        FileDes *file_des = FSFolder_Open_FileDes(self, filepath);
        instream = InStream_new(file_des);

        /* Leave 1 refcount in file_des's new owner, instream. */
        DECREF(file_des);
    }

    /* Still no?  Try harder to get a virtual file. */
    if (instream == NULL) {
        cf_reader = S_get_cf_reader(self, filepath);
        if (    cf_reader != NULL
            &&  cf_reader != (CompoundFileReader*)UNDEF
            && CFReader_Exists(cf_reader, filepath)
        ) {
            instream = CFReader_Open_In(cf_reader, filepath);
        }
    }

    return instream;
}

FileDes*
FSFolder_open_filedes(FSFolder *self, const CharBuf *filepath)
{
    CharBuf *fullpath = S_full_path(self, filepath);
#if (defined(CHY_HAS_SYS_MMAN_H) || defined(CHY_HAS_WINDOWS_H))
    MMapFileDes *file_des = MMapFileDes_new(fullpath);
#else
    FSFileDes *file_des = FSFileDes_new(fullpath, "r");
#endif

    DECREF(fullpath);

    if (file_des == NULL)
        THROW(ERR, "Can't open '%o': %s", filepath, strerror(errno));

    return (FileDes*)file_des;
}

void
FSFolder_mkdir(FSFolder *self, const CharBuf *path)
{
    CharBuf *dir = S_full_path(self, path);
    DirManip_create_dir(dir);
    DECREF(dir);
}

VArray*
FSFolder_list(FSFolder *self)
{
    VArray *real_files = DirManip_list_files(self->path);
    u32_t   num_files  = real_files ? VA_Get_Size(real_files) : 0;
    VArray *files      = VA_new(num_files);
    VArray *vfiles     = VA_new(num_files);
    u32_t i, max;
    u32_t num_vfiles = 0;

    /* Accumulate virtual files. */
    for (i = 0; i < num_files; i++) {
        CharBuf *filepath = (CharBuf*)VA_Fetch(real_files, i);
        if (CB_Ends_With_Str(filepath, "cfmeta.json", 11)) {
            CompoundFileReader *cf_reader = S_get_cf_reader(self, filepath);
            if (cf_reader) {
                VArray *seg_vfiles = CFReader_List(cf_reader);
                num_vfiles += VA_Get_Size(seg_vfiles);
                VA_Push(vfiles, (Obj*)seg_vfiles);
            }
        }
        else if (CB_Ends_With_Str(filepath, ".cf", 3)) { }
        else if (CB_Ends_With_Str(filepath, "cf.dat", 6)) { }
        else {
            VA_Push(files, INCREF(filepath));
        }
    }

    /* Add virtual files to output array. */
    VA_Grow(files, VA_Get_Size(files) + num_vfiles);
    for (i = 0, max = VA_Get_Size(vfiles); i < max; i++) {
        VArray *seg_vfiles = (VArray*)VA_Fetch(vfiles, i);
        VA_Push_VArray(files, seg_vfiles);
    }
    DECREF(real_files);
    DECREF(vfiles);

    return files;
}

ZombieCharBuf
S_derive_seg_name(const CharBuf *filepath)
{
    ZombieCharBuf retval = ZCB_make(filepath);
    if (CB_Starts_With_Str(filepath, "seg_", 4)) {
        ZombieCharBuf temp = ZCB_make(filepath);
        size_t len = ZCB_Nip(&temp, 4);
        while (isalnum(ZCB_Code_Point_At(&temp, 0))) {
            len += ZCB_Nip(&temp, 1);
        }
        ZCB_Truncate(&retval, len);
    }
    else {
        ZCB_Set_Size(&retval, 0);
    }
    return retval;
}

static CompoundFileReader*
S_get_cf_reader(FSFolder *self, const CharBuf *filepath)
{
    ZombieCharBuf seg_name = S_derive_seg_name(filepath);
    CompoundFileReader *cf_reader = (CompoundFileReader*)Hash_Fetch(
        self->cf_readers, (Obj*)&seg_name);

    if (CB_Ends_With_Str(filepath, "segmeta.json", 12)) { return NULL; } 
    else if (cf_reader == (CompoundFileReader*)UNDEF) { return NULL; }
    else if (cf_reader == NULL) {
        CharBuf *cf_file         = CB_newf("%o/cf.dat", &seg_name);
        CharBuf *cfmeta_file     = CB_newf("%o/cfmeta.json", &seg_name);
        if (   FSFolder_Real_Exists(self, cf_file)
            && FSFolder_Real_Exists(self, cfmeta_file)
        ) {
            cf_reader = CFReader_new(self, (CharBuf*)&seg_name);
            if (cf_reader) {
                Hash_Store(self->cf_readers, (Obj*)&seg_name, 
                    (Obj*)cf_reader);
            }
        }
        else {
            Hash_Store(self->cf_readers, (Obj*)&seg_name, (Obj*)UNDEF);
        }
        DECREF(cf_file);
        DECREF(cfmeta_file);
    }

    return cf_reader;
}

bool_t
FSFolder_exists(FSFolder *self, const CharBuf *filepath)
{
    CompoundFileReader *cf_reader;
    if (NULL != (cf_reader = S_get_cf_reader(self, filepath))) {
        return CFReader_Exists(cf_reader, filepath);
    }
    else {
        return FSFolder_Real_Exists(self, filepath);
    }
}

bool_t
FSFolder_real_exists(FSFolder *self, const CharBuf *filepath)
{
    struct stat sb;
    CharBuf *fullpath = S_full_path(self, filepath);
    bool_t retval = false;
    if (stat((char*)CB_Get_Ptr8(fullpath), &sb) != -1)
        retval = true;
    DECREF(fullpath);
    return retval;
}

void
FSFolder_rename(FSFolder *self, const CharBuf* from, const CharBuf *to)
{
    CharBuf *from_path = S_full_path(self, from);
    CharBuf *to_path   = S_full_path(self, to);
    if (rename((char*)CB_Get_Ptr8(from_path), (char*)CB_Get_Ptr8(to_path)) ) {
        THROW(ERR, "rename from '%o' to '%o' failed: %s", from_path, to_path, 
            strerror(errno));
    }
    DECREF(to_path);
    DECREF(from_path);
}

bool_t
FSFolder_hard_link(FSFolder *self, const CharBuf *source, 
                   const CharBuf *target)
{
    CharBuf *source_path = S_full_path(self, source);
    CharBuf *target_path = S_full_path(self, target);
    bool_t retval = DirManip_hard_link(source_path, target_path);
    DECREF(source_path);
    DECREF(target_path);
    return retval;
}

bool_t
FSFolder_delete(FSFolder *self, const CharBuf *filepath)
{
    CompoundFileReader *cf_reader;

    if (   NULL != (cf_reader = S_get_cf_reader(self, filepath))
        && CFReader_Exists(self, filepath)
    ) {
        i32_t num_left = CFReader_Get_Size(cf_reader);
        if (num_left > 1) {
            CFReader_Delete_Virtual(cf_reader, filepath);
            return true;
        }
        else { /* last virtual file */
            ZombieCharBuf seg_name = S_derive_seg_name(filepath);
            CharBuf *cf_file = CB_newf("%o%s%o%scf.dat", self->path,
                DIR_SEP, &seg_name, DIR_SEP);
            CharBuf *cfmeta_file = CB_newf("%o%s%o%scfmeta.json", self->path,
                DIR_SEP, &seg_name, DIR_SEP);

            /* Try to delete the data file first.  If unsuccessful, return
             * false, leaving the virtual file alone. */
            CFReader_Close(cf_reader);
            if ( !DirManip_delete(cf_file) ) {
                DECREF(cf_file);
                DECREF(cfmeta_file);
                return false;
            }

            /* Now try to delete the metadata file.  If the data file gets
             * deleted but this stays behind it's a problem, so throw an
             * exception.
             */
            if ( !DirManip_delete(cfmeta_file) ) {
                CharBuf *mess = MAKE_MESS( "Couldn't delete cf meta file "
                    "while deleting virtual file '%o'", filepath);
                DECREF(cf_file);
                DECREF(cfmeta_file);
                Err_throw_mess(ERR, mess);
            }

            CFReader_Delete_Virtual(cf_reader, filepath);
            Hash_Delete(self->cf_readers, (Obj*)&seg_name);
            DECREF(cf_reader);
            DECREF(cf_file);
            DECREF(cfmeta_file);
            return true;
        }
    }
    else {
        return FSFolder_Delete_Real(self, filepath);
    }
}

bool_t
FSFolder_delete_real(FSFolder *self, const CharBuf *filepath)
{
    CharBuf *fullpath = S_full_path(self, filepath);
    bool_t result;
    if (   CB_Ends_With_Str(filepath, ".cf", 3)
        || CB_Ends_With_Str(filepath, ".cfmeta", 7)
        || CB_Ends_With_Str(filepath, "cf.dat", 6)
        || CB_Ends_With_Str(filepath, "cfmeta.json", 11)
    ) {
        ZombieCharBuf seg_name = S_derive_seg_name(filepath);
        DECREF(Hash_Delete(self->cf_readers, (Obj*)&seg_name));
    }
    result = DirManip_delete(fullpath);
    DECREF(fullpath);
    return result;
}

void
FSFolder_close(FSFolder *self)
{
    UNUSED_VAR(self);
}

void
FSFolder_finish_segment(FSFolder *self, const CharBuf *seg_name)
{
    CompoundFileWriter *cf_writer = CFWriter_new(self, seg_name);
    CFWriter_Consolidate(cf_writer);
    DECREF(Hash_Delete(self->cf_readers, (Obj*)seg_name));
    DECREF(cf_writer);
}

static CharBuf*
S_full_path(FSFolder *self, const CharBuf *filepath)
{
    CharBuf *fullpath = CB_new(200);
    CB_Cat(fullpath, self->path);
    CB_Cat_Trusted_Str(fullpath, DIR_SEP, sizeof(DIR_SEP) - 1);
    CB_Cat(fullpath, filepath);
    if (DIR_SEP[0] != '/') {
        CB_Swap_Chars(fullpath, '/', DIR_SEP[0]);
    }
    return fullpath;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

