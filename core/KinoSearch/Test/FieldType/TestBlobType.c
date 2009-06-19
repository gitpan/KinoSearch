#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/FieldType/TestBlobType.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/FieldType/BlobType.h"
#include "KinoSearch/Analysis/Tokenizer.h"

static void
test_Dump_Load_and_Equals(TestBatch *batch)
{
    BlobType *type            = BlobType_new();
    Obj      *dump            = (Obj*)BlobType_Dump(type);
    Obj      *clone           = Obj_Load(dump, dump);
    Obj      *another_dump    = (Obj*)BlobType_Dump_For_Schema(type);
    BlobType *another_clone   = BlobType_load(NULL, another_dump);

    ASSERT_TRUE(batch, BlobType_Equals(type, (Obj*)clone), 
        "Dump => Load round trip");
    ASSERT_TRUE(batch, BlobType_Equals(type, (Obj*)another_clone), 
        "Dump_For_Schema => Load round trip");

    DECREF(type);
    DECREF(dump);
    DECREF(clone);
    DECREF(another_dump);
    DECREF(another_clone);
}

void
TestBlobType_run_tests()
{
    TestBatch *batch = Test_new_batch("TestBlobType", 2, NULL);
    PLAN(batch);
    test_Dump_Load_and_Equals(batch);
    batch->destroy(batch);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

