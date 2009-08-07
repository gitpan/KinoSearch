#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Test/Obj/TestByteBuf.h"

static void
test_I32_functions(TestBatch *batch)
{
    i32_t ints[] = { -1, 0, 2 };
    ByteBuf *bb = BB_new_bytes(&ints, sizeof(ints));
    ASSERT_INT_EQ(batch, BB_Get_Size(bb), BB_I32_Size(bb) * sizeof(i32_t), 
        "I32_Size");
    ASSERT_INT_EQ(batch, BB_I32_Get(bb, 0), -1, "I32_Get");
    ASSERT_INT_EQ(batch, BB_I32_Get(bb, 1),  0, "I32_Get");
    ASSERT_INT_EQ(batch, BB_I32_Get(bb, 2),  2, "I32_Get");
    DECREF(bb);
}

static void
test_Grow(TestBatch *batch)
{
    ByteBuf *bb = BB_new(1);
    ASSERT_INT_EQ(batch, BB_Get_Capacity(bb), 8,
        "Allocate in 8-byte increments");
    BB_Grow(bb, 9);
    ASSERT_INT_EQ(batch, BB_Get_Capacity(bb), 16, 
        "Grow in 8-byte increments");
    DECREF(bb);
}

void
TestBB_run_tests()
{
    TestBatch *batch = Test_new_batch("TestByteBuf", 6, NULL);
    PLAN(batch);

    test_Grow(batch);
    test_I32_functions(batch);

    batch->destroy(batch);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

