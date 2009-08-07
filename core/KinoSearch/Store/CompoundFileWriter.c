#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Store/CompoundFileWriter.h"
#include "KinoSearch/Store/FSFolder.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/Compat/DirManip.h"
#include "KinoSearch/Util/I32Array.h"
#include "KinoSearch/Util/Json.h"

i32_t CFWriter_current_file_format = 1;

/* Helper which does the heavy lifting for CFWriter_consolidate. */
void
do_consolidate(CompoundFileWriter *self);

/* Clean up files which may be left over from previous merge attempts. */
static void
S_clean_up_old_temp_files(CompoundFileWriter *self);

/* Write JSON-encoded metadata to .cfmeta file. */
static void
S_write_cfmeta(CompoundFileWriter *self, Hash *sub_files);

CompoundFileWriter*
CFWriter_new(FSFolder *folder, const CharBuf *seg_name)
{
    CompoundFileWriter *self 
        = (CompoundFileWriter*)VTable_Make_Obj(COMPOUNDFILEWRITER);
    return CFWriter_init(self, folder, seg_name);
}

CompoundFileWriter*
CFWriter_init(CompoundFileWriter *self, FSFolder *folder, 
              const CharBuf *seg_name)
{
    self->folder   = (FSFolder*)INCREF(folder);
    self->seg_name = CB_Clone(seg_name);
    return self;
}

void
CFWriter_destroy(CompoundFileWriter *self)
{
    DECREF(self->folder);
    DECREF(self->seg_name);
    FREE_OBJ(self);
}

void
CFWriter_consolidate(CompoundFileWriter *self)
{
    CharBuf *cfmeta_filename = CB_newf("%o/cfmeta.json", self->seg_name);
    if (FSFolder_Real_Exists(self->folder, cfmeta_filename)) {
        DECREF(cfmeta_filename);
        THROW(ERR, "Merge already performed for segment %o", self->seg_name);
    }
    else {
        DECREF(cfmeta_filename);
        S_clean_up_old_temp_files(self);
        do_consolidate(self);
    }
}

static void
S_clean_up_old_temp_files(CompoundFileWriter *self)
{
    FSFolder *folder            = self->folder;
    CharBuf  *seg_name          = self->seg_name;
    CharBuf  *cf_file           = CB_newf("%o/cf.dat", seg_name);
    CharBuf  *cf_meta_temp_file = CB_newf("%o/cfmeta.json.temp", seg_name);

    if (FSFolder_Real_Exists(folder, cf_file)) {
        if (!FSFolder_Delete_Real(folder, cf_file)) {
            CharBuf *mess = MAKE_MESS("Can't delete '%o'", cf_file);
            DECREF(cf_file);
            DECREF(cf_meta_temp_file);
            Err_throw_mess(ERR, mess);
        }
    }
    if (FSFolder_Real_Exists(folder, cf_meta_temp_file)) {
        if (!FSFolder_Delete_Real(folder, cf_meta_temp_file)) {
            CharBuf *mess = MAKE_MESS("Can't delete '%o'", cf_meta_temp_file);
            DECREF(cf_file);
            DECREF(cf_meta_temp_file);
            Err_throw_mess(ERR, mess);
        }
    }
    DECREF(cf_file);
    DECREF(cf_meta_temp_file);
}

void
do_consolidate(CompoundFileWriter *self)
{
    FSFolder  *folder       = self->folder;
    CharBuf   *seg_name     = self->seg_name;
    Hash      *metadata     = Hash_new(0);
    Hash      *sub_files    = Hash_new(0);
    CharBuf   *folder_path  = CB_newf("%o%s%o", Folder_Get_Path(folder),
                                DIR_SEP, seg_name);
    VArray    *real_files   = DirManip_list_files(folder_path);
    CharBuf   *outfilename  = CB_newf("%o/cf.dat", self->seg_name);
    CharBuf   *infilepath   = CB_new(30);
    OutStream *outstream    = FSFolder_Open_Out(folder, outfilename);
    u32_t      i, max;

    if (!outstream) { THROW(ERR, "Can't open %o", outfilename); }

    /* Start metadata. */
    Hash_Store_Str(metadata, "files", 5, INCREF(sub_files));
    Hash_Store_Str(metadata, "format", 6, 
        (Obj*)CB_newf("%i32", CFWriter_current_file_format) );

    VA_Sort(real_files, NULL, NULL);
    for (i = 0, max = VA_Get_Size(real_files); i < max; i++) {
        CharBuf *infilename = (CharBuf*)VA_Fetch(real_files, i);
        CB_setf(infilepath, "%o/%o", seg_name, infilename);

        if (!CB_Ends_With_Str(infilepath, ".json", 5)) {
            InStream *instream   = FSFolder_Open_In(folder, infilepath);
            i64_t     offset     = OutStream_Tell(outstream);
            Hash     *file_data  = Hash_new(2);
            i64_t     len;

            /* Absorb the file. */
            if (!instream) { THROW(ERR, "Failed to open %o", infilepath); }
            OutStream_Absorb(outstream, instream);
            len = OutStream_Tell(outstream) - offset;

            /* Record offset and length. */
            Hash_Store_Str(file_data, "offset", 6, 
                (Obj*)CB_newf("%i64", offset) );
            Hash_Store_Str(file_data, "length", 6, 
                (Obj*)CB_newf("%i64", len) );
            Hash_Store(sub_files, (Obj*)infilepath, (Obj*)file_data);

            /* Add filler NULL bytes so that every sub-file begins on a file
             * position multiple of 8. */
            {
                i64_t filler_bytes = (8 - (len % 8)) % 8;
                while (filler_bytes--) { OutStream_Write_U8(outstream, 0); }
            }

            InStream_Close(instream);
            DECREF(instream);
        }
    }

    /* Write metadata to cfmeta file. */
    S_write_cfmeta(self, metadata);

    /* Clean up. */
    OutStream_Close(outstream);
    DECREF(outstream);
    DECREF(real_files);
    DECREF(outfilename);
    DECREF(infilepath);
    DECREF(metadata);
    DECREF(folder_path);
    {
        CharBuf *merged_file;
        Obj     *ignore;
        Hash_Iter_Init(sub_files);
        while (Hash_Iter_Next(sub_files, (Obj**)&merged_file, &ignore)) {
            if (!FSFolder_Delete_Real(folder, merged_file)) {
                CharBuf *mess = MAKE_MESS("Can't delete '%o'", merged_file);
                DECREF(sub_files);
                Err_throw_mess(ERR, mess);
            }
        }
    }
    DECREF(sub_files);
}

static void
S_write_cfmeta(CompoundFileWriter *self, Hash *sub_files)
{ 
    CharBuf *seg_name        = self->seg_name;
    CharBuf *outfilename     = CB_newf("%o/cfmeta.json.temp", seg_name);
    CharBuf *commit_filename = CB_newf("%o/cfmeta.json", seg_name);

    /* Get an OutStream, blast out JSON-encoded file entries. */
    Json_spew_json((Obj*)sub_files, (Folder*)self->folder, outfilename);

    /* Perform commit. */
    FSFolder_Rename(self->folder, outfilename, commit_filename);

    /* Clean up. */ 
    DECREF(commit_filename);
    DECREF(outfilename);
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

