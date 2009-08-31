#define C_KINO_TESTMATCHALLQUERY
#include "KinoSearch/Util/ToolSet.h"
#include <math.h>

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Test/Search/TestMatchAllQuery.h"
#include "KinoSearch/Search/MatchAllQuery.h"

static void
test_Dump_Load_and_Equals(TestBatch *batch)
{
    MatchAllQuery *query = MatchAllQuery_new();
    Obj           *dump  = (Obj*)MatchAllQuery_Dump(query);
    MatchAllQuery *clone = (MatchAllQuery*)MatchAllQuery_Load(query, dump);

    ASSERT_TRUE(batch, MatchAllQuery_Equals(query, (Obj*)clone), 
        "Dump => Load round trip");
    ASSERT_FALSE(batch, MatchAllQuery_Equals(query, (Obj*)&EMPTY), "Equals");

    DECREF(query);
    DECREF(dump);
    DECREF(clone);
}


void
TestMatchAllQuery_run_tests()
{
    TestBatch *batch = Test_new_batch("TestMatchAllQuery", 2, NULL);
    PLAN(batch);
    test_Dump_Load_and_Equals(batch);
    batch->destroy(batch);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

