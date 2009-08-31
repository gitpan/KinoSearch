#define C_KINO_TESTNOMATCHQUERY
#include "KinoSearch/Util/ToolSet.h"
#include <math.h>

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Test/Search/TestNoMatchQuery.h"
#include "KinoSearch/Search/NoMatchQuery.h"

static void
test_Dump_Load_and_Equals(TestBatch *batch)
{
    NoMatchQuery *query = NoMatchQuery_new();
    Obj          *dump  = (Obj*)NoMatchQuery_Dump(query);
    NoMatchQuery *clone = (NoMatchQuery*)NoMatchQuery_Load(query, dump);

    ASSERT_TRUE(batch, NoMatchQuery_Equals(query, (Obj*)clone), 
        "Dump => Load round trip");
    ASSERT_FALSE(batch, NoMatchQuery_Equals(query, (Obj*)&EMPTY), "Equals");

    DECREF(query);
    DECREF(dump);
    DECREF(clone);
}


void
TestNoMatchQuery_run_tests()
{
    TestBatch *batch = Test_new_batch("TestNoMatchQuery", 2, NULL);
    PLAN(batch);
    test_Dump_Load_and_Equals(batch);
    batch->destroy(batch);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

