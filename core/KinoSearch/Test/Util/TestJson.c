#define C_KINO_CHARBUF
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Util/TestJson.h"
#include "KinoSearch/Util/Json.h"
#include "KinoSearch/Store/FileHandle.h"
#include "KinoSearch/Store/RAMFolder.h"

static CharBuf foo           = ZCB_LITERAL("foo");
static CharBuf bar           = ZCB_LITERAL("bar");
static CharBuf boffo         = ZCB_LITERAL("boffo");

/* Create a test data structure including at least one each of Hash, VArray,
 * and CharBuf. */
static Obj* 
S_make_dump()
{
    Hash *dump = Hash_new(0);
    Hash_Store_Str(dump, "foo", 3, (Obj*)CB_newf("foo"));
    Hash_Store_Str(dump, "stuff", 5, (Obj*)VA_new(0));
    return (Obj*)dump;
}

static void
test_to_and_from(TestBatch *batch)
{
    Obj *dump = S_make_dump();
    CharBuf *json = Json_to_json(dump);
    Obj *got = Json_from_json(json);
    ASSERT_TRUE(batch, got != NULL && Obj_Equals(dump, got), 
        "Round trip through to_json and from_json");
    DECREF(dump);
    DECREF(json);
    DECREF(got);
}

static void
test_spew_and_slurp(TestBatch *batch)
{
    Obj *dump = S_make_dump();
    Folder *folder = (Folder*)RAMFolder_new(NULL);
    bool_t result;
    Obj *got;

    result = Json_spew_json(dump, folder, &foo);
    ASSERT_TRUE(batch, result, "spew_json returns true on success");
    ASSERT_TRUE(batch, Folder_Exists(folder, (CharBuf*)&foo), 
        "spew_json wrote file");

    got = Json_slurp_json(folder, &foo);
    ASSERT_TRUE(batch, got && Obj_Equals(dump, got), 
        "Round trip through spew_json and slurp_json");
    DECREF(got);

    Err_set_error(NULL);
    result = Json_spew_json(dump, folder, &foo);
    ASSERT_FALSE(batch, result, "Can't spew_json when file exists");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Failed spew_json sets Err_error");
    
    Err_set_error(NULL);
    got = Json_slurp_json(folder, &bar);
    ASSERT_TRUE(batch, got == NULL, 
        "slurp_json returns NULL when file doesn't exist");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Failed slurp_json sets Err_error");

    {
        FileHandle *fh = Folder_Open_FileHandle(folder, &boffo,
            FH_CREATE | FH_WRITE_ONLY );
        FH_Write(fh, "garbage", 7);
        DECREF(fh);
    }
    Err_set_error(NULL);
    got = Json_slurp_json(folder, &boffo);
    ASSERT_TRUE(batch, got == NULL, 
        "slurp_json returns NULL when file doesn't contain valid JSON");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Failed slurp_json sets Err_error");
    DECREF(got);

    DECREF(dump);
    DECREF(folder);
}

void
TestJson_run_tests()
{
    TestBatch *batch = TestBatch_new(10);

    TestBatch_Plan(batch);
    test_to_and_from(batch);
    test_spew_and_slurp(batch);

    DECREF(batch);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

