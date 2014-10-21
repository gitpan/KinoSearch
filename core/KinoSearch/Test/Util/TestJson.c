#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Util/TestJson.h"
#include "KinoSearch/Util/Json.h"
#include "KinoSearch/Store/FileHandle.h"
#include "KinoSearch/Store/RAMFolder.h"

// Create a test data structure including at least one each of Hash, VArray,
// and CharBuf.
static Obj* 
S_make_dump()
{
    Hash *dump = Hash_new(0);
    Hash_Store_Str(dump, "foo", 3, (Obj*)CB_newf("foo"));
    Hash_Store_Str(dump, "stuff", 5, (Obj*)VA_new(0));
    return (Obj*)dump;
}

// Test escapes for control characters ASCII 0-31.
static char* control_escapes[] = {
    "\\u0000",
    "\\u0001",
    "\\u0002",
    "\\u0003",
    "\\u0004",
    "\\u0005",
    "\\u0006",
    "\\u0007",
    "\\b",
    "\\t",
    "\\n",
    "\\u000b",
    "\\f",
    "\\r",
    "\\u000e",
    "\\u000f",
    "\\u0010",
    "\\u0011",
    "\\u0012",
    "\\u0013",
    "\\u0014",
    "\\u0015",
    "\\u0016",
    "\\u0017",
    "\\u0018",
    "\\u0019",
    "\\u001a",
    "\\u001b",
    "\\u001c",
    "\\u001d",
    "\\u001e",
    "\\u001f",
    NULL
};

// Test quote and backslash escape in isolation, then in context.
static char* quote_escapes_source[] = {
    "\"",
    "\\",
    "abc\"",
    "abc\\",
    "\"xyz",
    "\\xyz",
    "\\\"",
    "\"\\",
    NULL
};
static char* quote_escapes_json[] = {
    "\\\"",
    "\\\\",
    "abc\\\"",
    "abc\\\\",
    "\\\"xyz",
    "\\\\xyz",
    "\\\\\\\"",
    "\\\"\\\\",
    NULL
};

static void
test_escapes(TestBatch *batch)
{
    CharBuf *string      = CB_new(10);
    CharBuf *json_wanted = CB_new(10);

    for (int i = 0; control_escapes[i] != NULL; i++) {
        CB_Truncate(string, 0);
        CB_Cat_Char(string, i);
        char    *escaped = control_escapes[i];
        CharBuf *json    = Json_encode_string(string);
        CharBuf *decoded = Json_decode_string(json);

        CB_setf(json_wanted, "\"%s\"", escaped);
        CB_Trim(json);
        TEST_TRUE(batch, json != NULL && CB_Equals(json_wanted, (Obj*)json),
            "encode control escape: %s", escaped);

        TEST_TRUE(batch, decoded != NULL && CB_Equals(string, (Obj*)decoded), 
            "decode control escape: %s", escaped);

        DECREF(json);
        DECREF(decoded);
    }

    for (int i = 0; quote_escapes_source[i] != NULL; i++) {
        char *source  = quote_escapes_source[i];
        char *escaped = quote_escapes_json[i];
        CB_setf(string, source, strlen(source));
        CharBuf *json    = Json_encode_string(string);
        CharBuf *decoded = Json_decode_string(json);

        CB_setf(json_wanted, "\"%s\"", escaped);
        CB_Trim(json);
        TEST_TRUE(batch, json != NULL && CB_Equals(json_wanted, (Obj*)json),
            "encode quote/backslash escapes: %s", source);

        TEST_TRUE(batch, decoded != NULL && CB_Equals(string, (Obj*)decoded), 
            "decode quote/backslash escapes: %s", source);

        DECREF(json);
        DECREF(decoded);
    }

    DECREF(json_wanted);
    DECREF(string);
}

static void
test_to_and_from(TestBatch *batch)
{
    Obj *dump = S_make_dump();
    CharBuf *json = Json_to_json(dump);
    Obj *got = Json_from_json(json);
    TEST_TRUE(batch, got != NULL && Obj_Equals(dump, got), 
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

    CharBuf *foo = (CharBuf*)ZCB_WRAP_STR("foo", 3);
    bool_t result = Json_spew_json(dump, folder, foo);
    TEST_TRUE(batch, result, "spew_json returns true on success");
    TEST_TRUE(batch, Folder_Exists(folder, foo), 
        "spew_json wrote file");

    Obj *got = Json_slurp_json(folder, foo);
    TEST_TRUE(batch, got && Obj_Equals(dump, got), 
        "Round trip through spew_json and slurp_json");
    DECREF(got);

    Err_set_error(NULL);
    result = Json_spew_json(dump, folder, foo);
    TEST_FALSE(batch, result, "Can't spew_json when file exists");
    TEST_TRUE(batch, Err_get_error() != NULL, 
        "Failed spew_json sets Err_error");
    
    Err_set_error(NULL);
    CharBuf *bar = (CharBuf*)ZCB_WRAP_STR("bar", 3);
    got = Json_slurp_json(folder, bar);
    TEST_TRUE(batch, got == NULL, 
        "slurp_json returns NULL when file doesn't exist");
    TEST_TRUE(batch, Err_get_error() != NULL, 
        "Failed slurp_json sets Err_error");

    CharBuf *boffo = (CharBuf*)ZCB_WRAP_STR("boffo", 5);
    {
        FileHandle *fh = Folder_Open_FileHandle(folder, boffo,
            FH_CREATE | FH_WRITE_ONLY );
        FH_Write(fh, "garbage", 7);
        DECREF(fh);
    }
    Err_set_error(NULL);
    got = Json_slurp_json(folder, boffo);
    TEST_TRUE(batch, got == NULL, 
        "slurp_json returns NULL when file doesn't contain valid JSON");
    TEST_TRUE(batch, Err_get_error() != NULL, 
        "Failed slurp_json sets Err_error");
    DECREF(got);

    DECREF(dump);
    DECREF(folder);
}

void
TestJson_run_tests()
{
    TestBatch *batch = TestBatch_new(90);

    TestBatch_Plan(batch);
    test_to_and_from(batch);
    test_escapes(batch);
    test_spew_and_slurp(batch);

    DECREF(batch);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

