#define C_KINO_TESTSTEMMER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Analysis/TestStemmer.h"
#include "KinoSearch/Analysis/Stemmer.h"

static ZombieCharBuf EN = ZCB_LITERAL("en");
static ZombieCharBuf ES = ZCB_LITERAL("es");

static void
test_Dump_Load_and_Equals(TestBatch *batch)
{
    Stemmer *stemmer     = Stemmer_new((CharBuf*)&EN);
    Stemmer *other       = Stemmer_new((CharBuf*)&ES);
    Obj     *dump        = (Obj*)Stemmer_Dump(stemmer);
    Obj     *other_dump  = (Obj*)Stemmer_Dump(other);
    Stemmer *clone       = (Stemmer*)Stemmer_Load(other, dump);
    Stemmer *other_clone = (Stemmer*)Stemmer_Load(other, other_dump);

    ASSERT_FALSE(batch, Stemmer_Equals(stemmer,
        (Obj*)other), "Equals() false with different language");
    ASSERT_TRUE(batch, Stemmer_Dump_Equals(other,
        (Obj*)other_dump), "Dump_Equals()");
    ASSERT_TRUE(batch, Stemmer_Dump_Equals(stemmer,
        (Obj*)dump), "Dump_Equals()");
    ASSERT_FALSE(batch, Stemmer_Dump_Equals(stemmer,
        (Obj*)other_dump), "Dump_Equals() false with different language");
    ASSERT_FALSE(batch, Stemmer_Dump_Equals(other,
        (Obj*)dump), "Dump_Equals() false with different language");
    ASSERT_TRUE(batch, Stemmer_Equals(stemmer,
        (Obj*)clone), "Dump => Load round trip");
    ASSERT_TRUE(batch, Stemmer_Equals(other,
        (Obj*)other_clone), "Dump => Load round trip");

    DECREF(stemmer);
    DECREF(dump);
    DECREF(clone);
    DECREF(other);
    DECREF(other_dump);
    DECREF(other_clone);
}

void
TestStemmer_run_tests()
{
    TestBatch *batch = Test_new_batch("TestStemmer", 7, NULL);

    PLAN(batch);

    test_Dump_Load_and_Equals(batch);

    batch->destroy(batch);
}


/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

