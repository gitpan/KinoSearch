#define C_KINO_TESTNUM
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Test/Object/TestNum.h"

static void
test_To_String(TestBatch *batch)
{
    Float32   *f32 = Float32_new(1.33f);
    Float64   *f64 = Float64_new(1.33);
    Integer32 *i32 = Int32_new(I32_MAX);
    Integer64 *i64 = Int64_new(I64_MAX);
    CharBuf *f32_string = Float32_To_String(f32);
    CharBuf *f64_string = Float64_To_String(f64);
    CharBuf *i32_string = Int32_To_String(i32);
    CharBuf *i64_string = Int64_To_String(i64);

    ASSERT_TRUE(batch, CB_Starts_With_Str(f32_string, "1.3", 3),
        "Float32_To_String");
    ASSERT_TRUE(batch, CB_Starts_With_Str(f64_string, "1.3", 3),
        "Float64_To_String");
    ASSERT_TRUE(batch, CB_Equals_Str(i32_string, "2147483647", 10), 
        "Int32_To_String");
    ASSERT_TRUE(batch, CB_Equals_Str(i64_string, "9223372036854775807", 19),
        "Int64_To_String");

    DECREF(i64_string);
    DECREF(i32_string);
    DECREF(f64_string);
    DECREF(f32_string);
    DECREF(i64);
    DECREF(i32);
    DECREF(f64);
    DECREF(f32);
}

static void
test_accessors(TestBatch *batch)
{
    Float32   *f32 = Float32_new(1.0);
    Float64   *f64 = Float64_new(1.0);
    Integer32 *i32 = Int32_new(1);
    Integer64 *i64 = Int64_new(1);

    Float32_Set_Value(f32, 1.33f);
    ASSERT_FLOAT_EQ(batch, Float32_Get_Value(f32), 1.33f, 
        "F32 Set_Value Get_Value");

    Float64_Set_Value(f64, 1.33);
    ASSERT_TRUE(batch, Float64_Get_Value(f64) == 1.33, 
        "F64 Set_Value Get_Value");

    ASSERT_TRUE(batch, Float32_To_I64(f32) == 1, "Float32_To_I64");
    ASSERT_TRUE(batch, Float64_To_I64(f64) == 1, "Float64_To_I64");

    ASSERT_TRUE(batch, Float32_To_F64(f32) == 1.33f, "Float32_To_F64");
    ASSERT_TRUE(batch, Float64_To_F64(f64) == 1.33, "Float64_To_F64");

    Int32_Set_Value(i32, I32_MIN);
    ASSERT_INT_EQ(batch, Int32_Get_Value(i32), I32_MIN, 
        "I32 Set_Value Get_Value");

    Int64_Set_Value(i64, I64_MIN);
    ASSERT_TRUE(batch, Int64_Get_Value(i64) == I64_MIN, 
        "I64 Set_Value Get_Value");

    Int32_Set_Value(i32, -1);
    Int64_Set_Value(i64, -1);
    ASSERT_TRUE(batch, Int32_To_F64(i32) == -1, "Int32_To_F64");
    ASSERT_TRUE(batch, Int64_To_F64(i64) == -1, "Int64_To_F64");

    DECREF(i64);
    DECREF(i32);
    DECREF(f64);
    DECREF(f32);
}

static void
test_Equals_and_Compare_To(TestBatch *batch)
{
    Float32   *f32 = Float32_new(1.0);
    Float64   *f64 = Float64_new(1.0);
    Integer32 *i32 = Int32_new(I32_MAX);
    Integer64 *i64 = Int64_new(I64_MAX);

    ASSERT_TRUE(batch, Float32_Compare_To(f32, (Obj*)f64) == 0, 
        "F32_Compare_To equal");
    ASSERT_TRUE(batch, Float32_Equals(f32, (Obj*)f64), 
        "F32_Equals equal");

    Float64_Set_Value(f64, 2.0);
    ASSERT_TRUE(batch, Float32_Compare_To(f32, (Obj*)f64) < 0, 
        "F32_Compare_To less than");
    ASSERT_FALSE(batch, Float32_Equals(f32, (Obj*)f64), 
        "F32_Equals less than");

    Float64_Set_Value(f64, 0.0);
    ASSERT_TRUE(batch, Float32_Compare_To(f32, (Obj*)f64) > 0, 
        "F32_Compare_To greater than");
    ASSERT_FALSE(batch, Float32_Equals(f32, (Obj*)f64), 
        "F32_Equals greater than");

    Float64_Set_Value(f64, 1.0);
    Float32_Set_Value(f32, 1.0);
    ASSERT_TRUE(batch, Float64_Compare_To(f64, (Obj*)f32) == 0, 
        "F64_Compare_To equal");
    ASSERT_TRUE(batch, Float64_Equals(f64, (Obj*)f32), 
        "F64_Equals equal");

    Float32_Set_Value(f32, 2.0);
    ASSERT_TRUE(batch, Float64_Compare_To(f64, (Obj*)f32) < 0, 
        "F64_Compare_To less than");
    ASSERT_FALSE(batch, Float64_Equals(f64, (Obj*)f32), 
        "F64_Equals less than");

    Float32_Set_Value(f32, 0.0);
    ASSERT_TRUE(batch, Float64_Compare_To(f64, (Obj*)f32) > 0, 
        "F64_Compare_To greater than");
    ASSERT_FALSE(batch, Float64_Equals(f64, (Obj*)f32), 
        "F64_Equals greater than");

    Float64_Set_Value(f64, I64_MAX * 2.0);
    ASSERT_TRUE(batch, Float64_Compare_To(f64, (Obj*)i64) > 0,
        "Float64 comparison to Integer64");
    ASSERT_TRUE(batch, Int64_Compare_To(i64, (Obj*)f64) < 0,
        "Integer64 comparison to Float64");

    Float32_Set_Value(f32, I32_MAX * 2.0f);
    ASSERT_TRUE(batch, Float32_Compare_To(f32, (Obj*)i32) > 0,
        "Float32 comparison to Integer32");
    ASSERT_TRUE(batch, Int32_Compare_To(i32, (Obj*)f32) < 0,
        "Integer32 comparison to Float32");

    DECREF(i64);
    DECREF(i32);
    DECREF(f64);
    DECREF(f32);
}

static void
test_Clone(TestBatch *batch)
{
    Float32   *f32 = Float32_new(1.33f);
    Float64   *f64 = Float64_new(1.33);
    Integer32 *i32 = Int32_new(I32_MAX);
    Integer64 *i64 = Int64_new(I64_MAX);
    Float32   *f32_dupe = Float32_Clone(f32);
    Float64   *f64_dupe = Float64_Clone(f64);
    Integer32 *i32_dupe = Int32_Clone(i32);
    Integer64 *i64_dupe = Int64_Clone(i64);
    ASSERT_TRUE(batch, Float32_Equals(f32, (Obj*)f32_dupe), 
        "Float32 Clone");
    ASSERT_TRUE(batch, Float64_Equals(f64, (Obj*)f64_dupe),
        "Float64 Clone");
    ASSERT_TRUE(batch, Int32_Equals(i32, (Obj*)i32_dupe), 
        "Integer32 Clone");
    ASSERT_TRUE(batch, Int64_Equals(i64, (Obj*)i64_dupe),
        "Integer64 Clone");
    DECREF(i64_dupe);
    DECREF(i32_dupe);
    DECREF(f64_dupe);
    DECREF(f32_dupe);
    DECREF(i64);
    DECREF(i32);
    DECREF(f64);
    DECREF(f32);
}

static void
test_serialization(TestBatch *batch)
{
    Float32   *f32 = Float32_new(1.33f);
    Float64   *f64 = Float64_new(1.33);
    Integer32 *i32 = Int32_new(-1);
    Integer64 *i64 = Int64_new(-1);
    Float32   *f32_thaw = (Float32*)TestUtils_freeze_thaw((Obj*)f32);
    Float64   *f64_thaw = (Float64*)TestUtils_freeze_thaw((Obj*)f64);
    Integer32 *i32_thaw = (Integer32*)TestUtils_freeze_thaw((Obj*)i32);
    Integer64 *i64_thaw = (Integer64*)TestUtils_freeze_thaw((Obj*)i64);

    ASSERT_TRUE(batch, Float32_Equals(f32, (Obj*)f32_thaw), 
        "Float32 freeze/thaw");
    ASSERT_TRUE(batch, Float64_Equals(f64, (Obj*)f64_thaw),
        "Float64 freeze/thaw");
    ASSERT_TRUE(batch, Int32_Equals(i32, (Obj*)i32_thaw), 
        "Integer32 freeze/thaw");
    ASSERT_TRUE(batch, Int64_Equals(i64, (Obj*)i64_thaw),
        "Integer64 freeze/thaw");

    DECREF(i64_thaw);
    DECREF(i32_thaw);
    DECREF(f64_thaw);
    DECREF(f32_thaw);
    DECREF(i64);
    DECREF(i32);
    DECREF(f64);
    DECREF(f32);
}

void
TestNum_run_tests()
{
    TestBatch *batch = TestBatch_new(38);
    TestBatch_Plan(batch);

    test_To_String(batch);
    test_accessors(batch);
    test_Equals_and_Compare_To(batch);
    test_Clone(batch);
    test_serialization(batch);
    
    DECREF(batch);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

