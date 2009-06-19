#include "KinoSearch/Util/ToolSet.h"
#include <stdarg.h>
#include <string.h>

#include "KinoSearch/Test/Util/TestCharBuf.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Search/LeafQuery.h"

static CharBuf*
S_get_cb(char *string)
{
    return CB_new_from_utf8(string, strlen(string));
}

TestCharBuf*
TestCB_new(CharBuf *wanted, CharBuf *got)
{
    TestCharBuf *self = (TestCharBuf*)VTable_Make_Obj(&TESTCHARBUF);
    return TestCB_init(self, wanted, got);
}

TestCharBuf*
TestCB_init(TestCharBuf *self, CharBuf *wanted, CharBuf *got)
{
    self->wanted   = wanted ? wanted : NULL;
    self->got      = got    ? got    : NULL;
    return self;
}

void
TestCB_destroy(TestCharBuf *self)
{
    DECREF(self->wanted);
    DECREF(self->got);
    FREE_OBJ(self);
}

static void
vcatf_s(VArray *tests)
{
    CharBuf *wanted = S_get_cb("foo bar bizzle baz");
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %s baz", "bizzle");
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_null_string(VArray *tests)
{
    CharBuf *wanted = S_get_cb("foo bar [NULL] baz");
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %s baz", NULL);
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_cb(VArray *tests)
{
    CharBuf *wanted = S_get_cb("foo bar ZEKE baz");
    CharBuf *catworthy = S_get_cb("ZEKE");
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %o baz", catworthy);
    DECREF(catworthy);
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_obj(VArray *tests)
{
    CharBuf   *wanted = S_get_cb("ooga content:FOO booga");
    LeafQuery *leaf_query = TestUtils_make_leaf_query("content", "FOO");
    CharBuf   *got = S_get_cb("ooga");
    CB_catf(got, " %o booga", leaf_query);
    DECREF(leaf_query);
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_null_obj(VArray *tests)
{
    CharBuf *wanted = S_get_cb("foo bar [NULL] baz");
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %o baz", NULL);
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_i8(VArray *tests)
{
    CharBuf *wanted = S_get_cb("foo bar -3 baz");
    i8_t num = -3;
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %i8 baz", num);
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_i32(VArray *tests)
{
    CharBuf *wanted = S_get_cb("foo bar -100000 baz");
    i32_t num = -100000;
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %i32 baz", num);
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_i64(VArray *tests)
{
    CharBuf *wanted = S_get_cb("foo bar -5000000000 baz");
    i64_t num = I64_C(-5000000000);
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %i64 baz", num);
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_u8(VArray *tests)
{
    CharBuf *wanted = S_get_cb("foo bar 3 baz");
    u8_t num = 3;
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %u8 baz", num);
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_u32(VArray *tests)
{
    CharBuf *wanted = S_get_cb("foo bar 100000 baz");
    u32_t num = 100000;
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %u32 baz", num);
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_u64(VArray *tests)
{
    CharBuf *wanted = S_get_cb("foo bar 5000000000 baz");
    u64_t num = U64_C(5000000000);
    CharBuf *got = S_get_cb("foo ");
    CB_catf(got, "bar %u64 baz", num);
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_f64(VArray *tests)
{
    CharBuf *wanted;
    char buf[64];
    float num = 1.3f;
    CharBuf *got = S_get_cb("foo ");
    sprintf(buf, "foo bar %g baz", num);
    wanted = CB_new_from_trusted_utf8(buf, strlen(buf));
    CB_catf(got, "bar %f64 baz", num);
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

static void
vcatf_x32(VArray *tests)
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
    VA_Push(tests, (Obj*)TestCB_new(wanted, got));
}

VArray*
TestCB_vcatf_tests()
{
    VArray *tests = VA_new(0);

    vcatf_s(tests);
    vcatf_null_string(tests);
    vcatf_cb(tests);
    vcatf_obj(tests);
    vcatf_null_obj(tests);
    vcatf_i8(tests);
    vcatf_i32(tests);
    vcatf_i64(tests);
    vcatf_u8(tests);
    vcatf_u32(tests);
    vcatf_u64(tests);
    vcatf_f64(tests);
    vcatf_x32(tests);
    
    return tests;
}

CharBuf*
TestCB_get_wanted(TestCharBuf *self) { return self->wanted; }
CharBuf*
TestCB_get_got(TestCharBuf *self)    { return self->got; }

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

