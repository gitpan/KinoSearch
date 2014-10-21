#define C_KINO_TESTNUMERICTYPE
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Plan/TestNumericType.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Plan/BlobType.h"
#include "KinoSearch/Plan/NumericType.h"

static void
test_Dump_Load_and_Equals(TestBatch *batch)
{
    Int32Type   *i32 = Int32Type_new();
    Int64Type   *i64 = Int64Type_new();
    Float32Type *f32 = Float32Type_new();
    Float64Type *f64 = Float64Type_new();

    TEST_FALSE(batch, Int32Type_Equals(i32, (Obj*)i64), 
        "Int32Type_Equals() false for different type");
    TEST_FALSE(batch, Int32Type_Equals(i32, NULL), 
        "Int32Type_Equals() false for NULL");

    TEST_FALSE(batch, Int64Type_Equals(i64, (Obj*)i32), 
        "Int64Type_Equals() false for different type");
    TEST_FALSE(batch, Int64Type_Equals(i64, NULL), 
        "Int64Type_Equals() false for NULL");

    TEST_FALSE(batch, Float32Type_Equals(f32, (Obj*)f64), 
        "Float32Type_Equals() false for different type");
    TEST_FALSE(batch, Float32Type_Equals(f32, NULL), 
        "Float32Type_Equals() false for NULL");

    TEST_FALSE(batch, Float64Type_Equals(f64, (Obj*)f32), 
        "Float64Type_Equals() false for different type");
    TEST_FALSE(batch, Float64Type_Equals(f64, NULL), 
        "Float64Type_Equals() false for NULL");

    {
        Obj *dump = (Obj*)Int32Type_Dump(i32);
        Obj *other = Obj_Load(dump, dump);
        TEST_TRUE(batch, Int32Type_Equals(i32, other), 
            "Dump => Load round trip for Int32Type");
        DECREF(dump);
        DECREF(other);
    }

    {
        Obj *dump = (Obj*)Int64Type_Dump(i64);
        Obj *other = Obj_Load(dump, dump);
        TEST_TRUE(batch, Int64Type_Equals(i64, other), 
            "Dump => Load round trip for Int64Type");
        DECREF(dump);
        DECREF(other);
    }

    {
        Obj *dump = (Obj*)Float32Type_Dump(f32);
        Obj *other = Obj_Load(dump, dump);
        TEST_TRUE(batch, Float32Type_Equals(f32, other), 
            "Dump => Load round trip for Float32Type");
        DECREF(dump);
        DECREF(other);
    }

    {
        Obj *dump = (Obj*)Float64Type_Dump(f64);
        Obj *other = Obj_Load(dump, dump);
        TEST_TRUE(batch, Float64Type_Equals(f64, other), 
            "Dump => Load round trip for Float64Type");
        DECREF(dump);
        DECREF(other);
    }

    DECREF(i32);
    DECREF(i64);
    DECREF(f32);
    DECREF(f64);
}

void
TestNumericType_run_tests()
{
    TestBatch *batch = TestBatch_new(12);
    TestBatch_Plan(batch);
    test_Dump_Load_and_Equals(batch);
    DECREF(batch);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

