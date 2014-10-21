#define C_KINO_TESTTERMQUERY
#include "KinoSearch/Util/ToolSet.h"
#include <math.h>

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Search/TestTermQuery.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Search/TermQuery.h"

static void
test_Dump_Load_and_Equals(TestBatch *batch)
{
    TermQuery *query         = TestUtils_make_term_query("content", "foo");
    TermQuery *field_differs = TestUtils_make_term_query("stuff", "foo");
    TermQuery *term_differs  = TestUtils_make_term_query("content", "bar");
    TermQuery *boost_differs = TestUtils_make_term_query("content", "foo");
    Obj       *dump          = (Obj*)TermQuery_Dump(query);
    TermQuery *clone         = (TermQuery*)TermQuery_Load(term_differs, dump);

    TEST_FALSE(batch, TermQuery_Equals(query, (Obj*)field_differs),
        "Equals() false with different field");
    TEST_FALSE(batch, TermQuery_Equals(query, (Obj*)term_differs),
        "Equals() false with different term");
    TermQuery_Set_Boost(boost_differs, 0.5);
    TEST_FALSE(batch, TermQuery_Equals(query, (Obj*)boost_differs),
        "Equals() false with different boost");
    TEST_TRUE(batch, TermQuery_Equals(query, (Obj*)clone), 
        "Dump => Load round trip");

    DECREF(query);
    DECREF(term_differs);
    DECREF(field_differs);
    DECREF(boost_differs);
    DECREF(dump);
    DECREF(clone);
}

void
TestTermQuery_run_tests()
{
    TestBatch *batch = TestBatch_new(4);
    TestBatch_Plan(batch);
    test_Dump_Load_and_Equals(batch);
    DECREF(batch);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

