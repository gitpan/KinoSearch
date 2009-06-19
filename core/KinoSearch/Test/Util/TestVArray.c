#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Util/TestVArray.h"

static void
test_Equals(TestBatch *batch)
{
    VArray *array  = VA_new(0);
    VArray *other  = VA_new(0);

    ASSERT_TRUE(batch, VA_Equals(array, (Obj*)other), 
        "Empty arrays are equal");

    VA_Push(array, INCREF(&EMPTY));
    ASSERT_FALSE(batch, VA_Equals(array, (Obj*)other), 
        "Add one elem and Equals returns false");

    VA_Push(other, INCREF(&EMPTY));
    ASSERT_TRUE(batch, VA_Equals(array, (Obj*)other), 
        "Add a matching elem and Equals returns true");

    VA_Store(array, 2, INCREF(&EMPTY));
    ASSERT_FALSE(batch, VA_Equals(array, (Obj*)other), 
        "Add elem after a NULL and Equals returns false");

    VA_Store(other, 2, INCREF(&EMPTY));
    ASSERT_TRUE(batch, VA_Equals(array, (Obj*)other), 
        "Empty elems don't spoil Equals");

    VA_Store(other, 2, INCREF(&UNDEFINED));
    ASSERT_FALSE(batch, VA_Equals(array, (Obj*)other), 
        "Non-matching value spoils Equals");

    VA_Splice(array, 1, 2); /* removes empty elems */
    VA_Delete(other, 1);    /* leaves NULL in place of deleted elem */
    VA_Delete(other, 2);
    ASSERT_FALSE(batch, VA_Equals(array, (Obj*)other), 
        "Empty trailing elements spoil Equals");

    DECREF(array);
    DECREF(other);
}

static void
test_Dump_and_Load(TestBatch *batch)
{
    VArray *array  = VA_new(0);
    Obj    *dump;
    VArray *loaded;

    VA_Push(array, (Obj*)CB_new_from_trusted_utf8("foo", 3));
    dump = (Obj*)VA_Dump(array);
    loaded = (VArray*)Obj_Load(dump, dump);
    ASSERT_TRUE(batch, VA_Equals(array, (Obj*)loaded), 
        "Dump => Load round trip");

    DECREF(array);
    DECREF(dump);
    DECREF(loaded);
}

void
TestVArray_run_tests()
{
    TestBatch *batch = Test_new_batch("TestVArray", 8, NULL);

    PLAN(batch);

    test_Equals(batch);
    test_Dump_and_Load(batch);

    batch->destroy(batch);
}


/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

