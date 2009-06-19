#include "KinoSearch/Util/ToolSet.h"
#include <stdlib.h>

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Util/TestIntArrays.h"
#include "KinoSearch/Util/IntArrays.h"

static u32_t*
S_random_ints(size_t count, u32_t max) {
    u32_t *ints = CALLOCATE(count, u32_t);
    size_t i;
    for (i = 0; i < count; i++) {
        ints[i] = rand() % (max + 1);
    }
    return ints;
}

static void
test_u1(TestBatch *batch)
{
    size_t count = 8;
    u32_t *ints = S_random_ints(count, 1);
    u8_t  *bits = CALLOCATE(2, u8_t);
    size_t i;

    for (i = 0; i < count; i++) {
        if (ints[i]) { IntArr_u1set(bits, i); }
    }
    for (i = 0; i < count; i++) {
        ASSERT_INT_EQ(batch, IntArr_u1get(bits, i), ints[i], "u1");
    }

    MemMan_wrapped_free(bits);
    MemMan_wrapped_free(ints);
}

static void
test_u2(TestBatch *batch)
{
    size_t count = 32;
    u32_t *ints = S_random_ints(count, 3);
    u8_t  *bits = CALLOCATE((128/4), u8_t);
    size_t i;

    for (i = 0; i < count; i++) {
        IntArr_u2set(bits, i, ints[i]);
    }
    for (i = 0; i < count; i++) {
        ASSERT_INT_EQ(batch, IntArr_u2get(bits, i), ints[i], "u2");
    }

    MemMan_wrapped_free(bits);
    MemMan_wrapped_free(ints);
}

static void
test_u4(TestBatch *batch)
{
    size_t count = 128;
    u32_t *ints = S_random_ints(count, 15);
    u8_t  *bits = CALLOCATE((1024/2), u8_t);
    size_t i;

    for (i = 0; i < count; i++) {
        IntArr_u4set(bits, i, ints[i]);
    }
    for (i = 0; i < count; i++) {
        ASSERT_INT_EQ(batch, IntArr_u4get(bits, i), ints[i], "u4");
    }

    MemMan_wrapped_free(bits);
    MemMan_wrapped_free(ints);
}

void
TestIntArrays_run_tests()
{
    TestBatch *batch = Test_new_batch("TestIntArrays", 168, NULL);

    PLAN(batch);

    test_u1(batch);
    test_u2(batch);
    test_u4(batch);

    batch->destroy(batch);
}


/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

