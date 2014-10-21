#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Index/TestSnapshot.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Store/RAMFolder.h"

static void
test_Add_and_Delete(TestBatch *batch)
{
    Snapshot *snapshot = Snapshot_new();
    CharBuf *foo = (CharBuf*)ZCB_WRAP_STR("foo", 3);
    CharBuf *bar = (CharBuf*)ZCB_WRAP_STR("bar", 3);

    Snapshot_Add_Entry(snapshot, foo);
    Snapshot_Add_Entry(snapshot, foo); // redundant
    VArray *entries = Snapshot_List(snapshot);
    TEST_INT_EQ(batch, Snapshot_Num_Entries(snapshot), 1, 
        "One entry added");
    TEST_TRUE(batch, CB_Equals(foo, VA_Fetch(entries, 0)), "correct entry");
    DECREF(entries);

    Snapshot_Add_Entry(snapshot, bar);
    TEST_INT_EQ(batch, Snapshot_Num_Entries(snapshot), 2, 
        "second entry added");
    Snapshot_Delete_Entry(snapshot, foo);
    TEST_INT_EQ(batch, Snapshot_Num_Entries(snapshot), 1, "Delete_Entry");

    DECREF(snapshot);
}

static void
test_path_handling(TestBatch *batch)
{
    Snapshot *snapshot = Snapshot_new();
    Folder   *folder   = (Folder*)RAMFolder_new(NULL);
    CharBuf  *snap     = (CharBuf*)ZCB_WRAP_STR("snap", 4);
    CharBuf  *crackle  = (CharBuf*)ZCB_WRAP_STR("crackle", 7);

    Snapshot_Write_File(snapshot, folder, snap);
    TEST_TRUE(batch, CB_Equals(snap, (Obj*)Snapshot_Get_Path(snapshot)),
        "Write_File() sets path as a side effect");

    Folder_Rename(folder, snap, crackle);
    Snapshot_Read_File(snapshot, folder, crackle);
    TEST_TRUE(batch, CB_Equals(crackle, (Obj*)Snapshot_Get_Path(snapshot)),
        "Read_File() sets path as a side effect");

    Snapshot_Set_Path(snapshot, snap);
    TEST_TRUE(batch, CB_Equals(snap, (Obj*)Snapshot_Get_Path(snapshot)),
        "Set_Path()");

    DECREF(folder);
    DECREF(snapshot);
}

static void
test_Read_File_and_Write_File(TestBatch *batch)
{
    Snapshot *snapshot = Snapshot_new();
    Folder   *folder   = (Folder*)RAMFolder_new(NULL);
    CharBuf  *snap     = (CharBuf*)ZCB_WRAP_STR("snap", 4);
    CharBuf  *foo      = (CharBuf*)ZCB_WRAP_STR("foo", 3);

    Snapshot_Add_Entry(snapshot, foo);
    Snapshot_Write_File(snapshot, folder, snap);

    Snapshot *dupe = Snapshot_new();
    Snapshot *read_retval = Snapshot_Read_File(dupe, folder, snap);
    TEST_TRUE(batch, dupe == read_retval, "Read_File() returns the object");

    VArray *orig_list = Snapshot_List(snapshot);
    VArray *dupe_list = Snapshot_List(dupe);
    TEST_TRUE(batch, VA_Equals(orig_list, (Obj*)dupe_list), 
        "Round trip through Write_File() and Read_File()");

    DECREF(orig_list);
    DECREF(dupe_list);
    DECREF(dupe);
    DECREF(snapshot);
    DECREF(folder);
}

void
TestSnapshot_run_tests()
{
    TestBatch *batch = TestBatch_new(9);
    TestBatch_Plan(batch);
    test_Add_and_Delete(batch);
    test_path_handling(batch);
    test_Read_File_and_Write_File(batch);
    DECREF(batch);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

