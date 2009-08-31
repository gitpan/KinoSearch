#define C_KINO_TESTCHARBUF
#include "KinoSearch/Util/ToolSet.h"
#include <stdarg.h>
#include <string.h>
#include <stdio.h>

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Test/Obj/TestCharBuf.h"
#include "KinoSearch/Search/LeafQuery.h"

static CharBuf*
S_get_cb(char *string)
{
    return CB_new_from_utf8(string, strlen(string));
}

static void
test_vcatf_s(TestBatch *batch)
{
    CharBuf *wanted = S_get_cb("foo bar bizzle baz");
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %s baz", "bizzle");
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%s");
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_null_string(TestBatch *batch)
{
    CharBuf *wanted = S_get_cb("foo bar [NULL] baz");
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %s baz", NULL);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%s NULL");
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_cb(TestBatch *batch)
{
    CharBuf *wanted = S_get_cb("foo bar ZEKE baz");
    CharBuf *catworthy = S_get_cb("ZEKE");
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %o baz", catworthy);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%o CharBuf");
    DECREF(catworthy);
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_obj(TestBatch *batch)
{
    CharBuf   *wanted = S_get_cb("ooga content:FOO booga");
    LeafQuery *leaf_query = TestUtils_make_leaf_query("content", "FOO");
    CharBuf   *got = S_get_cb("ooga");
    CB_catf(got, " %o booga", leaf_query);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%o Obj");
    DECREF(leaf_query);
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_null_obj(TestBatch *batch)
{
    CharBuf *wanted = S_get_cb("foo bar [NULL] baz");
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %o baz", NULL);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%o NULL");
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_i8(TestBatch *batch)
{
    CharBuf *wanted = S_get_cb("foo bar -3 baz");
    i8_t num = -3;
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %i8 baz", num);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%i8");
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_i32(TestBatch *batch)
{
    CharBuf *wanted = S_get_cb("foo bar -100000 baz");
    i32_t num = -100000;
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %i32 baz", num);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%i32");
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_i64(TestBatch *batch)
{
    CharBuf *wanted = S_get_cb("foo bar -5000000000 baz");
    i64_t num = I64_C(-5000000000);
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %i64 baz", num);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%i64");
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_u8(TestBatch *batch)
{
    CharBuf *wanted = S_get_cb("foo bar 3 baz");
    u8_t num = 3;
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %u8 baz", num);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%u8");
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_u32(TestBatch *batch)
{
    CharBuf *wanted = S_get_cb("foo bar 100000 baz");
    u32_t num = 100000;
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %u32 baz", num);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%u32");
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_u64(TestBatch *batch)
{
    CharBuf *wanted = S_get_cb("foo bar 5000000000 baz");
    u64_t num = U64_C(5000000000);
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %u64 baz", num);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%u64");
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_f64(TestBatch *batch)
{
    CharBuf *wanted;
    char buf[64];
    float num = 1.3f;
    CharBuf *got = S_get_cb("foo ");
    sprintf(buf, "foo bar %g baz", num);
    wanted = CB_new_from_trusted_utf8(buf, strlen(buf));
    CB_catf(got, "bar %f64 baz", num);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%f64");
    DECREF(wanted);
    DECREF(got);
}

static void
test_vcatf_x32(TestBatch *batch)
{
    CharBuf *wanted;
    char buf[64];
    unsigned long num = I32_MAX;
    CharBuf *got = S_get_cb("foo ");
#if (SIZEOF_LONG == 4)
    sprintf(buf, "foo bar %.8lx baz", num);
#elif (SIZEOF_INT == 4)
    sprintf(buf, "foo bar %.8x baz", (unsigned)num);
#endif
    wanted = CB_new_from_trusted_utf8(buf, strlen(buf));
    CB_catf(got, "bar %x32 baz", (u32_t)num);
    ASSERT_TRUE(batch, CB_Equals(wanted, (Obj*)got), "%%x32");
    DECREF(wanted);
    DECREF(got);
}

void
TestCB_run_tests()
{
    TestBatch *batch = Test_new_batch("TestCharBuf", 13, NULL);
    PLAN(batch);

    test_vcatf_s(batch);
    test_vcatf_null_string(batch);
    test_vcatf_cb(batch);
    test_vcatf_obj(batch);
    test_vcatf_null_obj(batch);
    test_vcatf_i8(batch);
    test_vcatf_i32(batch);
    test_vcatf_i64(batch);
    test_vcatf_u8(batch);
    test_vcatf_u32(batch);
    test_vcatf_u64(batch);
    test_vcatf_f64(batch);
    test_vcatf_x32(batch);

    batch->destroy(batch);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

