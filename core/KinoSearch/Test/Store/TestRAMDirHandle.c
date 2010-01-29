#define C_KINO_RAMFOLDER
#define C_KINO_CHARBUF
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Store/TestRAMDirHandle.h"
#include "KinoSearch/Store/FileHandle.h"
#include "KinoSearch/Store/RAMFolder.h"
#include "KinoSearch/Store/RAMDirHandle.h"

static CharBuf foo           = ZCB_LITERAL("foo");
static CharBuf boffo         = ZCB_LITERAL("boffo");
static CharBuf foo_boffo     = ZCB_LITERAL("foo/boffo");

static void
test_all(TestBatch *batch)
{
    RAMFolder    *folder = RAMFolder_new(NULL);
    FileHandle   *fh;
    RAMDirHandle *dh;
    CharBuf      *entry;
    bool_t        saw_foo       = false;
    bool_t        saw_boffo     = false;
    bool_t        foo_was_dir   = false;
    bool_t        boffo_was_dir = false; 
    int           count         = 0;

    RAMFolder_MkDir(folder, &foo);
    fh = RAMFolder_Open_FileHandle(folder, &boffo, FH_CREATE | FH_WRITE_ONLY);
    DECREF(fh);
    fh = RAMFolder_Open_FileHandle(folder, &foo_boffo, 
        FH_CREATE | FH_WRITE_ONLY );
    DECREF(fh);

    dh = RAMDH_new(folder);
    entry = RAMDH_Get_Entry(dh);
    while (RAMDH_Next(dh)) {
        count++;
        if (CB_Equals(entry, (Obj*)&foo)) { 
            saw_foo = true;
            foo_was_dir = RAMDH_Entry_Is_Dir(dh);
        }
        else if (CB_Equals(entry, (Obj*)&boffo)) {
            saw_boffo = true;
            boffo_was_dir = RAMDH_Entry_Is_Dir(dh);
        }
    }
    ASSERT_INT_EQ(batch, 2, count, "correct number of entries");
    ASSERT_TRUE(batch, saw_foo, "Directory was iterated over");
    ASSERT_TRUE(batch, foo_was_dir, 
        "Dir correctly identified by Entry_Is_Dir");
    ASSERT_TRUE(batch, saw_boffo, "File was iterated over");
    ASSERT_FALSE(batch, boffo_was_dir, 
        "File correctly identified by Entry_Is_Dir");

    {
        u32_t refcount = RAMFolder_Get_RefCount(folder);
        RAMDH_Close(dh);
        ASSERT_INT_EQ(batch, RAMFolder_Get_RefCount(folder), refcount - 1,
            "Folder reference released by Close()");
    }

    DECREF(dh);
    DECREF(folder);
}

void
TestRAMDH_run_tests()
{
    TestBatch *batch = TestBatch_new(6);

    TestBatch_Plan(batch);
    test_all(batch);

    DECREF(batch);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

