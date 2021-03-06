#define C_KINO_RAMFOLDER
#define C_KINO_CHARBUF
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Store/TestRAMFolder.h"
#include "KinoSearch/Store/RAMFolder.h"
#include "KinoSearch/Store/DirHandle.h"
#include "KinoSearch/Store/RAMDirHandle.h"
#include "KinoSearch/Store/RAMFileHandle.h"

static CharBuf foo           = ZCB_LITERAL("foo");
static CharBuf bar           = ZCB_LITERAL("bar");
static CharBuf baz           = ZCB_LITERAL("baz");
static CharBuf boffo         = ZCB_LITERAL("boffo");
static CharBuf banana        = ZCB_LITERAL("banana");
static CharBuf foo_bar       = ZCB_LITERAL("foo/bar");
static CharBuf foo_bar_baz   = ZCB_LITERAL("foo/bar/baz");
static CharBuf foo_bar_boffo = ZCB_LITERAL("foo/bar/boffo");
static CharBuf foo_boffo     = ZCB_LITERAL("foo/boffo");
static CharBuf foo_foo       = ZCB_LITERAL("foo/foo");
static CharBuf nope          = ZCB_LITERAL("nope");
static CharBuf nope_nyet     = ZCB_LITERAL("nope/nyet");

static void
test_Initialize_and_Check(TestBatch *batch)
{
    RAMFolder *folder = RAMFolder_new(NULL);
    RAMFolder_Initialize(folder);
    PASS(batch, "Initialized concludes without incident");
    TEST_TRUE(batch, RAMFolder_Check(folder), "Check succeeds");
    DECREF(folder);
}

static void
test_Local_Exists(TestBatch *batch)
{
    RAMFolder *folder = RAMFolder_new(NULL);
    FileHandle *fh = RAMFolder_Open_FileHandle(folder, &boffo, 
        FH_CREATE | FH_WRITE_ONLY);
    DECREF(fh);
    RAMFolder_Local_MkDir(folder, &foo);

    TEST_TRUE(batch, RAMFolder_Local_Exists(folder, &boffo), 
        "Local_Exists() returns true for file");
    TEST_TRUE(batch, RAMFolder_Local_Exists(folder, &foo), 
        "Local_Exists() returns true for dir");
    TEST_FALSE(batch, RAMFolder_Local_Exists(folder, &bar), 
        "Local_Exists() returns false for non-existent entry");

    DECREF(folder);
}

static void
test_Local_Is_Directory(TestBatch *batch)
{
    RAMFolder *folder = RAMFolder_new(NULL);
    FileHandle *fh = RAMFolder_Open_FileHandle(folder, &boffo, 
        FH_CREATE | FH_WRITE_ONLY);
    DECREF(fh);
    RAMFolder_Local_MkDir(folder, &foo);

    TEST_FALSE(batch, RAMFolder_Local_Is_Directory(folder, &boffo), 
        "Local_Is_Directory() returns false for file");
    TEST_TRUE(batch, RAMFolder_Local_Is_Directory(folder, &foo), 
        "Local_Is_Directory() returns true for dir");
    TEST_FALSE(batch, RAMFolder_Local_Is_Directory(folder, &bar), 
        "Local_Is_Directory() returns false for non-existent entry");

    DECREF(folder);
}

static void
test_Local_Find_Folder(TestBatch *batch)
{
    RAMFolder *folder = RAMFolder_new(NULL);
    RAMFolder *local;
    FileHandle *fh;

    RAMFolder_MkDir(folder, &foo);
    RAMFolder_MkDir(folder, &foo_bar);
    fh = RAMFolder_Open_FileHandle(folder, &boffo, 
        FH_CREATE | FH_WRITE_ONLY);
    DECREF(fh);
    fh = RAMFolder_Open_FileHandle(folder, &foo_boffo, 
        FH_CREATE | FH_WRITE_ONLY);
    DECREF(fh);

    local = (RAMFolder*)RAMFolder_Local_Find_Folder(folder, &nope);
    TEST_TRUE(batch, local == NULL, "Non-existent entry yields NULL");

    local = (RAMFolder*)RAMFolder_Local_Find_Folder(folder, (CharBuf*)&EMPTY);
    TEST_TRUE(batch, local == NULL, "Empty string yields NULL");

    local = (RAMFolder*)RAMFolder_Local_Find_Folder(folder, &foo_bar);
    TEST_TRUE(batch, local == NULL, "nested folder yields NULL");

    local = (RAMFolder*)RAMFolder_Local_Find_Folder(folder, &foo_boffo);
    TEST_TRUE(batch, local == NULL, "nested file yields NULL");

    local = (RAMFolder*)RAMFolder_Local_Find_Folder(folder, &boffo);
    TEST_TRUE(batch, local == NULL, "local file yields NULL");
    
    local = (RAMFolder*)RAMFolder_Local_Find_Folder(folder, &bar);
    TEST_TRUE(batch, local == NULL, "name of nested folder yields NULL");

    local = (RAMFolder*)RAMFolder_Local_Find_Folder(folder, &foo);
    TEST_TRUE(batch, 
        local 
        && RAMFolder_Is_A(local, RAMFOLDER)
        && CB_Equals_Str(RAMFolder_Get_Path(local), "foo", 3), 
        "Find local directory");

    DECREF(folder);
}

static void
test_Local_MkDir(TestBatch *batch)
{
    RAMFolder *folder = RAMFolder_new(NULL);
    bool_t result;

    result = RAMFolder_Local_MkDir(folder, &foo);
    TEST_TRUE(batch, result, "Local_MkDir succeeds and returns true");

    Err_set_error(NULL);
    result = RAMFolder_Local_MkDir(folder, &foo);
    TEST_FALSE(batch, result, 
        "Local_MkDir returns false when a dir already exists");
    TEST_TRUE(batch, Err_get_error() != NULL, 
        "Local_MkDir sets Err_error when a dir already exists");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo), 
        "Existing dir untouched after failed Local_MkDir");

    {
        FileHandle *fh = RAMFolder_Open_FileHandle(folder, &boffo, 
            FH_CREATE | FH_WRITE_ONLY);
        DECREF(fh);
        Err_set_error(NULL);
        result = RAMFolder_Local_MkDir(folder, &foo);
        TEST_FALSE(batch, result, 
            "Local_MkDir returns false when a file already exists");
        TEST_TRUE(batch, Err_get_error() != NULL, 
            "Local_MkDir sets Err_error when a file already exists");
        TEST_TRUE(batch, RAMFolder_Exists(folder, &boffo) &&
            !RAMFolder_Local_Is_Directory(folder, &boffo), 
            "Existing file untouched after failed Local_MkDir");
    }

    DECREF(folder);
}

static void
test_Local_Open_Dir(TestBatch *batch)
{
    RAMFolder *folder = RAMFolder_new(NULL);
    DirHandle *dh = RAMFolder_Local_Open_Dir(folder);
    TEST_TRUE(batch, dh && DH_Is_A(dh, RAMDIRHANDLE), 
        "Local_Open_Dir returns a RAMDirHandle");
    DECREF(dh);
    DECREF(folder);
}

static void
test_Local_Open_FileHandle(TestBatch *batch)
{
    RAMFolder *folder = RAMFolder_new(NULL);
    FileHandle *fh;

    fh = RAMFolder_Local_Open_FileHandle(folder, &boffo, 
        FH_CREATE | FH_WRITE_ONLY);
    TEST_TRUE(batch, fh && FH_Is_A(fh, RAMFILEHANDLE), 
        "opened FileHandle");
    DECREF(fh);

    fh = RAMFolder_Local_Open_FileHandle(folder, &boffo, 
        FH_CREATE | FH_WRITE_ONLY);
    TEST_TRUE(batch, fh && FH_Is_A(fh, RAMFILEHANDLE), 
        "opened FileHandle for append");
    DECREF(fh);

    Err_set_error(NULL);
    fh = RAMFolder_Local_Open_FileHandle(folder, &boffo, 
        FH_CREATE | FH_WRITE_ONLY | FH_EXCLUSIVE);
    TEST_TRUE(batch, fh == NULL, "FH_EXLUSIVE flag prevents open");
    TEST_TRUE(batch, Err_get_error() != NULL,
        "failure due to FH_EXLUSIVE flag sets Err_error");

    fh = RAMFolder_Local_Open_FileHandle(folder, &boffo, FH_READ_ONLY);
    TEST_TRUE(batch, fh && FH_Is_A(fh, RAMFILEHANDLE), 
        "opened FileHandle for reading");
    DECREF(fh);

    Err_set_error(NULL);
    fh = RAMFolder_Local_Open_FileHandle(folder, &nope, FH_READ_ONLY);
    TEST_TRUE(batch, fh == NULL, 
        "Can't open non-existent file for reading");
    TEST_TRUE(batch, Err_get_error() != NULL,
        "Opening non-existent file for reading sets Err_error");

    DECREF(folder);
}

static void
test_Local_Delete(TestBatch *batch)
{
    RAMFolder *folder = RAMFolder_new(NULL);
    FileHandle *fh;
    
    fh = RAMFolder_Open_FileHandle(folder, &boffo, FH_CREATE | FH_WRITE_ONLY);
    DECREF(fh);
    TEST_TRUE(batch, RAMFolder_Local_Delete(folder, &boffo), 
        "Local_Delete on file succeeds");

    RAMFolder_Local_MkDir(folder, &foo);
    fh = RAMFolder_Open_FileHandle(folder, &foo_boffo, 
        FH_CREATE | FH_WRITE_ONLY);
    DECREF(fh);

    Err_set_error(NULL);
    TEST_FALSE(batch, RAMFolder_Local_Delete(folder, &foo), 
        "Local_Delete on non-empty dir fails");

    RAMFolder_Delete(folder, &foo_boffo);
    TEST_TRUE(batch, RAMFolder_Local_Delete(folder, &foo), 
        "Local_Delete on empty dir succeeds");

    DECREF(folder);
}

static void
test_Rename(TestBatch *batch)
{
    RAMFolder *folder = RAMFolder_new(NULL);
    FileHandle *fh;
    bool_t result;

    RAMFolder_MkDir(folder, &foo);
    RAMFolder_MkDir(folder, &foo_bar);
    fh = RAMFolder_Open_FileHandle(folder, &boffo, FH_CREATE | FH_WRITE_ONLY);
    DECREF(fh);

    // Move files. 

    result = RAMFolder_Rename(folder, &boffo, &banana); 
    TEST_TRUE(batch, result, "Rename succeeds and returns true");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &banana), 
        "File exists at new path");
    TEST_FALSE(batch, RAMFolder_Exists(folder, &boffo), 
        "File no longer exists at old path");

    result = RAMFolder_Rename(folder, &banana, &foo_bar_boffo); 
    TEST_TRUE(batch, result, "Rename to file in nested dir");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_bar_boffo), 
        "File exists at new path");
    TEST_FALSE(batch, RAMFolder_Exists(folder, &banana), 
        "File no longer exists at old path");

    result = RAMFolder_Rename(folder, &foo_bar_boffo, &boffo); 
    TEST_TRUE(batch, result, "Rename from file in nested dir");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &boffo), 
        "File exists at new path");
    TEST_FALSE(batch, RAMFolder_Exists(folder, &foo_bar_boffo), 
        "File no longer exists at old path");

    fh = RAMFolder_Open_FileHandle(folder, &foo_boffo, 
        FH_CREATE | FH_WRITE_ONLY);
    DECREF(fh);
    result = RAMFolder_Rename(folder, &boffo, &foo_boffo); 
    TEST_TRUE(batch, result, "Clobber");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_boffo), 
        "File exists at new path");
    TEST_FALSE(batch, RAMFolder_Exists(folder, &boffo), 
        "File no longer exists at old path");

    // Move Dirs. 

    RAMFolder_MkDir(folder, &baz);
    result = RAMFolder_Rename(folder, &baz, &boffo); 
    TEST_TRUE(batch, result, "Rename dir");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &boffo), 
        "Folder exists at new path");
    TEST_FALSE(batch, RAMFolder_Exists(folder, &baz), 
        "Folder no longer exists at old path");

    result = RAMFolder_Rename(folder, &boffo, &foo_foo); 
    TEST_TRUE(batch, result, "Rename dir into nested subdir");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_foo), 
        "Folder exists at new path");
    TEST_FALSE(batch, RAMFolder_Exists(folder, &boffo), 
        "Folder no longer exists at old path");

    result = RAMFolder_Rename(folder, &foo_foo, &foo_bar_baz); 
    TEST_TRUE(batch, result, "Rename dir from nested subdir");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_bar_baz), 
        "Folder exists at new path");
    TEST_FALSE(batch, RAMFolder_Exists(folder, &foo_foo), 
        "Folder no longer exists at old path");
    
    // Test failed clobbers. 

    Err_set_error(NULL);
    result = RAMFolder_Rename(folder, &foo_boffo, &foo_bar); 
    TEST_FALSE(batch, result, "Rename file clobbering dir fails");
    TEST_TRUE(batch, Err_get_error() != NULL, 
        "Failed rename sets Err_error");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_boffo), 
        "File still exists at old path");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_bar), 
        "Dir still exists after failed clobber");

    Err_set_error(NULL);
    result = RAMFolder_Rename(folder, &foo_bar, &foo_boffo); 
    TEST_FALSE(batch, result, "Rename dir clobbering file fails");
    TEST_TRUE(batch, Err_get_error() != NULL, 
        "Failed rename sets Err_error");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_bar), 
        "Dir still exists at old path");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_boffo), 
        "File still exists after failed clobber");

    // Test that "renaming" succeeds where to and from are the same. 

    result = RAMFolder_Rename(folder, &foo_boffo, &foo_boffo); 
    TEST_TRUE(batch, result, "Renaming file to itself succeeds");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_boffo), 
        "File still exists");

    result = RAMFolder_Rename(folder, &foo_bar, &foo_bar); 
    TEST_TRUE(batch, result, "Renaming dir to itself succeeds");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_bar), 
        "Dir still exists");

    // Invalid filepaths. 

    Err_set_error(NULL);
    result = RAMFolder_Rename(folder, &foo_boffo, &nope_nyet); 
    TEST_FALSE(batch, result, "Rename into non-existent subdir fails");
    TEST_TRUE(batch, Err_get_error() != NULL, 
        "Renaming into non-existent subdir sets Err_error");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_boffo), 
        "Entry still exists at old path");

    Err_set_error(NULL);
    result = RAMFolder_Rename(folder, &nope_nyet, &boffo); 
    TEST_FALSE(batch, result, "Rename non-existent file fails");
    TEST_TRUE(batch, Err_get_error() != NULL, 
        "Renaming non-existent source file sets Err_error");

    DECREF(folder);
}

static void
test_Hard_Link(TestBatch *batch)
{
    RAMFolder *folder = RAMFolder_new(NULL);
    FileHandle *fh;
    bool_t result;

    RAMFolder_MkDir(folder, &foo);
    RAMFolder_MkDir(folder, &foo_bar);
    fh = RAMFolder_Open_FileHandle(folder, &boffo, FH_CREATE | FH_WRITE_ONLY);
    DECREF(fh);

    // Link files. 

    result = RAMFolder_Hard_Link(folder, &boffo, &banana); 
    TEST_TRUE(batch, result, "Hard_Link succeeds and returns true");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &banana), 
        "File exists at new path");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &boffo), 
        "File still exists at old path");
    RAMFolder_Delete(folder, &boffo);

    result = RAMFolder_Hard_Link(folder, &banana, &foo_bar_boffo); 
    TEST_TRUE(batch, result, "Hard_Link to target within nested dir");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_bar_boffo), 
        "File exists at new path");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &banana), 
        "File still exists at old path");
    RAMFolder_Delete(folder, &banana);

    result = RAMFolder_Hard_Link(folder, &foo_bar_boffo, &foo_boffo); 
    TEST_TRUE(batch, result, "Hard_Link from file in nested dir");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_boffo), 
        "File exists at new path");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_bar_boffo), 
        "File still exists at old path");
    RAMFolder_Delete(folder, &foo_bar_boffo);

    // Invalid clobbers. 

    fh = RAMFolder_Open_FileHandle(folder, &boffo, FH_CREATE | FH_WRITE_ONLY);
    DECREF(fh);
    result = RAMFolder_Hard_Link(folder, &foo_boffo, &boffo); 
    TEST_FALSE(batch, result, "Clobber of file fails");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &boffo), 
        "File still exists at new path");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_boffo), 
        "File still exists at old path");
    RAMFolder_Delete(folder, &boffo);

    RAMFolder_MkDir(folder, &baz);
    result = RAMFolder_Hard_Link(folder, &foo_boffo, &baz); 
    TEST_FALSE(batch, result, "Clobber of dir fails");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &baz), 
        "Dir still exists at new path");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_boffo), 
        "File still exists at old path");
    RAMFolder_Delete(folder, &baz);

    // Invalid Hard_Link of dir. 

    RAMFolder_MkDir(folder, &baz);
    result = RAMFolder_Hard_Link(folder, &baz, &banana); 
    TEST_FALSE(batch, result, "Hard_Link dir fails");
    TEST_FALSE(batch, RAMFolder_Exists(folder, &banana), 
        "Nothing at new path");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &baz), 
        "Folder still exists at old path");
    RAMFolder_Delete(folder, &baz);

    // Test that linking to yourself fails. 

    result = RAMFolder_Hard_Link(folder, &foo_boffo, &foo_boffo); 
    TEST_FALSE(batch, result, "Hard_Link file to itself fails");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_boffo), 
        "File still exists");

    // Invalid filepaths. 

    Err_set_error(NULL);
    result = RAMFolder_Rename(folder, &foo_boffo, &nope_nyet); 
    TEST_FALSE(batch, result, "Hard_Link into non-existent subdir fails");
    TEST_TRUE(batch, Err_get_error() != NULL, 
        "Hard_Link into non-existent subdir sets Err_error");
    TEST_TRUE(batch, RAMFolder_Exists(folder, &foo_boffo), 
        "Entry still exists at old path");

    Err_set_error(NULL);
    result = RAMFolder_Rename(folder, &nope_nyet, &boffo); 
    TEST_FALSE(batch, result, "Hard_Link non-existent source file fails");
    TEST_TRUE(batch, Err_get_error() != NULL, 
        "Hard_Link non-existent source file sets Err_error");

    DECREF(folder);
}

static void
test_Close(TestBatch *batch)
{
    RAMFolder *folder = RAMFolder_new(NULL);
    RAMFolder_Close(folder);
    PASS(batch, "Close() concludes without incident");
    RAMFolder_Close(folder);
    RAMFolder_Close(folder);
    PASS(batch, "Calling Close() multiple times is safe");
    DECREF(folder);
}

void
TestRAMFolder_run_tests()
{
    TestBatch *batch = TestBatch_new(98);

    TestBatch_Plan(batch);
    test_Initialize_and_Check(batch);
    test_Local_Exists(batch);
    test_Local_Is_Directory(batch);
    test_Local_Find_Folder(batch);
    test_Local_MkDir(batch);
    test_Local_Open_Dir(batch);
    test_Local_Open_FileHandle(batch);
    test_Local_Delete(batch);
    test_Rename(batch);
    test_Hard_Link(batch);
    test_Close(batch);

    DECREF(batch);
}

/* Copyright 2005-2011 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

