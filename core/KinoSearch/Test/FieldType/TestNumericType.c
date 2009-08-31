#define C_KINO_TESTNUMERICTYPE
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/FieldType/TestNumericType.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/FieldType/BlobType.h"
#include "KinoSearch/FieldType/NumericType.h"

static void
test_Dump_Load_and_Equals(TestBatch *batch)
{
    Float64Type *type          = Float64Type_new();
    BlobType    *other         = BlobType_new();
    Obj         *dump          = (Obj*)Float64Type_Dump(type);
    Obj         *clone         = Obj_Load(dump, dump);
    Obj         *another_dump  = (Obj*)Float64Type_Dump_For_Schema(type);
    Float64Type *another_clone 
        = (Float64Type*)VTable_Load_Obj(FLOAT64TYPE, another_dump);

    ASSERT_FALSE(batch, Float64Type_Equals(type, (Obj*)other),
        "Equals() false with different FieldType");
    ASSERT_TRUE(batch, Float64Type_Equals(type, (Obj*)clone), 
        "Dump => Load round trip");
    ASSERT_TRUE(batch, Float64Type_Equals(type, (Obj*)another_clone), 
        "Dump_For_Schema => Load round trip");
    ASSERT_TRUE(batch, OBJ_IS_A(clone, FLOAT64TYPE), "Dump => Load Obj_Is_A");
    ASSERT_TRUE(batch, OBJ_IS_A(another_clone, FLOAT64TYPE), 
        "Dump_For_Schema => Load Obj_Is_A");

    DECREF(another_clone);
    DECREF(another_dump);
    DECREF(dump);
    DECREF(clone);
    DECREF(other);
    DECREF(type);
}

static void
test_Compare_Values(TestBatch *batch)
{
    Float64Type *type = Float64Type_new();
    Float64     *a    = Float64_new(1.0);
    Float64     *b    = Float64_new(2.0);

    ASSERT_TRUE(batch, 
        Float64Type_Compare_Values(type, (Obj*)a, (Obj*)b) < 0,
        "a less than b");
    ASSERT_TRUE(batch, 
        Float64Type_Compare_Values(type, (Obj*)b, (Obj*)a) > 0,
        "b greater than a");
    ASSERT_TRUE(batch, 
        Float64Type_Compare_Values(type, (Obj*)b, (Obj*)b) == 0,
        "b equals b");
    ASSERT_TRUE(batch, 
        Float64Type_Compare_Values(type, NULL, (Obj*)b) > 0,
        "NULL greater than b");
    ASSERT_TRUE(batch, 
        Float64Type_Compare_Values(type, (Obj*)b, NULL) < 0,
        "b less than NULL");
    ASSERT_TRUE(batch, 
        Float64Type_Compare_Values(type, NULL, NULL) == 0,
        "NULL equals NULL");

    DECREF(type);
    DECREF(a);
    DECREF(b);
}

void
TestNumericType_run_tests()
{
    TestBatch *batch = Test_new_batch("TestNumericType", 11, NULL);
    PLAN(batch);
    test_Dump_Load_and_Equals(batch);
    test_Compare_Values(batch);
    batch->destroy(batch);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

