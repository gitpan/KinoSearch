#define C_KINO_TESTI32ARRAY
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Object/TestI32Array.h"

static int32_t source_ints[] = { -1, 0, I32_MIN, I32_MAX, 1 };
static size_t num_ints = sizeof(source_ints) / sizeof(int32_t);

static void
test_all(TestBatch *batch)
{
    I32Array *i32_array = I32Arr_new(source_ints, num_ints);
    int32_t  *ints_copy = (int32_t*)malloc(num_ints * sizeof(int32_t));
    I32Array *stolen    = I32Arr_new_steal(ints_copy, num_ints);
    size_t    num_matched;

    memcpy(ints_copy, source_ints, num_ints * sizeof(int32_t));

    TEST_TRUE(batch, I32Arr_Get_Size(i32_array) == num_ints,
        "Get_Size");
    TEST_TRUE(batch, I32Arr_Get_Size(stolen) == num_ints,
        "Get_Size for stolen");

    for (num_matched = 0; num_matched < num_ints; num_matched++) {
        if (source_ints[num_matched] != I32Arr_Get(i32_array, num_matched)) {
            break; 
        }
    }
    TEST_INT_EQ(batch, num_matched, num_ints, 
        "Matched all source ints with Get()");

    for (num_matched = 0; num_matched < num_ints; num_matched++) {
        if (source_ints[num_matched] != I32Arr_Get(stolen, num_matched)) { 
            break; 
        }
    }
    TEST_INT_EQ(batch, num_matched, num_ints, 
        "Matched all source ints in stolen I32Array with Get()");

    DECREF(i32_array);
    DECREF(stolen);
}

void
TestI32Arr_run_tests()
{
    TestBatch *batch = TestBatch_new(4);

    TestBatch_Plan(batch);
    test_all(batch);

    DECREF(batch);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

