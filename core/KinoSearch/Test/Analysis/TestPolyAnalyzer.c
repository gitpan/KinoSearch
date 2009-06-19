#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Analysis/TestPolyAnalyzer.h"
#include "KinoSearch/Analysis/PolyAnalyzer.h"

static ZombieCharBuf EN = ZCB_LITERAL("en");
static ZombieCharBuf ES = ZCB_LITERAL("es");

static void
test_Dump_Load_and_Equals(TestBatch *batch)
{
    PolyAnalyzer *analyzer    = PolyAnalyzer_new((CharBuf*)&EN, NULL);
    PolyAnalyzer *other       = PolyAnalyzer_new((CharBuf*)&ES, NULL);
    Obj          *dump        = (Obj*)PolyAnalyzer_Dump(analyzer);
    Obj          *other_dump  = (Obj*)PolyAnalyzer_Dump(other);
    PolyAnalyzer *clone       = (PolyAnalyzer*)PolyAnalyzer_Load(other, dump);
    PolyAnalyzer *other_clone 
        = (PolyAnalyzer*)PolyAnalyzer_Load(other, other_dump);

    ASSERT_FALSE(batch, PolyAnalyzer_Equals(analyzer,
        (Obj*)other), "Equals() false with different language");
    ASSERT_TRUE(batch, PolyAnalyzer_Dump_Equals(other,
        (Obj*)other_dump), "Dump_Equals()");
    ASSERT_TRUE(batch, PolyAnalyzer_Dump_Equals(analyzer,
        (Obj*)dump), "Dump_Equals()");
    ASSERT_FALSE(batch, PolyAnalyzer_Dump_Equals(analyzer,
        (Obj*)other_dump), "Dump_Equals() false with different language");
    ASSERT_FALSE(batch, PolyAnalyzer_Dump_Equals(other,
        (Obj*)dump), "Dump_Equals() false with different language");
    ASSERT_TRUE(batch, PolyAnalyzer_Equals(analyzer,
        (Obj*)clone), "Dump => Load round trip");
    ASSERT_TRUE(batch, PolyAnalyzer_Equals(other,
        (Obj*)other_clone), "Dump => Load round trip");

    DECREF(analyzer);
    DECREF(dump);
    DECREF(clone);
    DECREF(other);
    DECREF(other_dump);
    DECREF(other_clone);
}

void
TestPolyAnalyzer_run_tests()
{
    TestBatch *batch = Test_new_batch("TestPolyAnalyzer", 7, NULL);

    PLAN(batch);

    test_Dump_Load_and_Equals(batch);

    batch->destroy(batch);
}


/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

