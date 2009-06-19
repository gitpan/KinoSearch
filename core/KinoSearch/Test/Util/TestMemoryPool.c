#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Util/TestMemoryPool.h"
#include "KinoSearch/Util/MemoryPool.h"

void
TestMemPool_run_tests()
{
    TestBatch  *batch     = Test_new_batch("TestPriQ", 4, NULL);
    MemoryPool *mem_pool  = MemPool_new(0);
    MemoryPool *other     = MemPool_new(0);
    char *ptr_a, *ptr_b;

    PLAN(batch);

    ptr_a = MemPool_Grab(mem_pool, 10);
    strcpy(ptr_a, "foo");
    MemPool_Release_All(mem_pool);

    ptr_b = MemPool_Grab(mem_pool, 10);
    ASSERT_STR_EQ(batch, ptr_b, "foo", "Recycle RAM on Release_All");

    ptr_a = mem_pool->buf;
    MemPool_Resize(mem_pool, ptr_b, 6);
    ASSERT_TRUE(batch, mem_pool->buf < ptr_a, "Resize");

    ptr_a = MemPool_Grab(other, 20);
    MemPool_Release_All(other);
    MemPool_Eat(other, mem_pool);
    ASSERT_TRUE(batch, other->buf == mem_pool->buf, "Eat");
    ASSERT_TRUE(batch, other->buf != NULL, "Eat");

    DECREF(mem_pool);
    DECREF(other);
    batch->destroy(batch);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

