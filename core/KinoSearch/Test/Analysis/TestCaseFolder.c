#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Analysis/TestCaseFolder.h"
#include "KinoSearch/Analysis/CaseFolder.h"

static void
test_Dump_Load_and_Equals(TestBatch *batch)
{
    CaseFolder *case_folder = CaseFolder_new();
    CaseFolder *other       = CaseFolder_new();
    Obj        *dump        = Obj_Dump(case_folder);
    CaseFolder *clone       = (CaseFolder*)Obj_Load(other, dump);

    ASSERT_TRUE(batch, Obj_Equals(case_folder, (Obj*)other), "Equals");
    ASSERT_TRUE(batch, CaseFolder_Dump_Equals(case_folder, (Obj*)dump), 
        "Dump_Equals");
    ASSERT_FALSE(batch, Obj_Equals(case_folder, (Obj*)&EMPTY), "Not Equals");
    ASSERT_TRUE(batch, Obj_Equals(case_folder, (Obj*)clone), 
        "Dump => Load round trip");

    DECREF(case_folder);
    DECREF(other);
    DECREF(dump);
    DECREF(clone);
}

void
TestCaseFolder_run_tests()
{
    TestBatch *batch = Test_new_batch("TestCaseFolder", 4, NULL);

    PLAN(batch);

    test_Dump_Load_and_Equals(batch);

    batch->destroy(batch);
}


/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

