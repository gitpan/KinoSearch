#define C_KINO_TESTFULLTEXTTYPE
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Plan/TestFullTextType.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Plan/FullTextType.h"
#include "KinoSearch/Analysis/CaseFolder.h"
#include "KinoSearch/Analysis/Tokenizer.h"

static void
test_Dump_Load_and_Equals(TestBatch *batch)
{
    Tokenizer    *tokenizer     = Tokenizer_new(NULL);
    CaseFolder   *case_folder   = CaseFolder_new();
    FullTextType *type          = FullTextType_new((Analyzer*)tokenizer);
    FullTextType *other         = FullTextType_new((Analyzer*)case_folder);
    FullTextType *boost_differs = FullTextType_new((Analyzer*)tokenizer);
    FullTextType *not_indexed   = FullTextType_new((Analyzer*)tokenizer);
    FullTextType *not_stored    = FullTextType_new((Analyzer*)tokenizer);
    FullTextType *highlightable = FullTextType_new((Analyzer*)tokenizer);
    Obj          *dump          = (Obj*)FullTextType_Dump(type);
    Obj          *clone         = Obj_Load(dump, dump);
    Obj          *another_dump  = (Obj*)FullTextType_Dump_For_Schema(type);

    FullTextType_Set_Boost(boost_differs, 1.5);
    FullTextType_Set_Indexed(not_indexed, false);
    FullTextType_Set_Stored(not_stored, false);
    FullTextType_Set_Highlightable(highlightable, true);

    // (This step is normally performed by Schema_Load() internally.) 
    Hash_Store_Str((Hash*)another_dump, "analyzer", 8, INCREF(tokenizer));
    FullTextType *another_clone = FullTextType_load(NULL, another_dump);

    TEST_FALSE(batch, FullTextType_Equals(type, (Obj*)boost_differs),
        "Equals() false with different boost");
    TEST_FALSE(batch, FullTextType_Equals(type, (Obj*)other),
        "Equals() false with different Analyzer");
    TEST_FALSE(batch, FullTextType_Equals(type, (Obj*)not_indexed),
        "Equals() false with indexed => false");
    TEST_FALSE(batch, FullTextType_Equals(type, (Obj*)not_stored),
        "Equals() false with stored => false");
    TEST_FALSE(batch, FullTextType_Equals(type, (Obj*)highlightable),
        "Equals() false with highlightable => true");
    TEST_TRUE(batch, FullTextType_Equals(type, (Obj*)clone), 
        "Dump => Load round trip");
    TEST_TRUE(batch, FullTextType_Equals(type, (Obj*)another_clone), 
        "Dump_For_Schema => Load round trip");

    DECREF(another_clone);
    DECREF(dump);
    DECREF(clone);
    DECREF(another_dump);
    DECREF(highlightable);
    DECREF(not_stored);
    DECREF(not_indexed);
    DECREF(boost_differs);
    DECREF(other);
    DECREF(type);
    DECREF(case_folder);
    DECREF(tokenizer);
}

static void
test_Compare_Values(TestBatch *batch)
{
    Tokenizer     *tokenizer = Tokenizer_new(NULL);
    FullTextType  *type      = FullTextType_new((Analyzer*)tokenizer);
    ZombieCharBuf *a         = ZCB_WRAP_STR("a", 1);
    ZombieCharBuf *b         = ZCB_WRAP_STR("b", 1);

    TEST_TRUE(batch, 
        FullTextType_Compare_Values(type, (Obj*)a, (Obj*)b) < 0,
        "a less than b");
    TEST_TRUE(batch, 
        FullTextType_Compare_Values(type, (Obj*)b, (Obj*)a) > 0,
        "b greater than a");
    TEST_TRUE(batch, 
        FullTextType_Compare_Values(type, (Obj*)b, (Obj*)b) == 0,
        "b equals b");

    DECREF(type);
    DECREF(tokenizer);
}

void
TestFullTextType_run_tests()
{
    TestBatch *batch = TestBatch_new(10);
    TestBatch_Plan(batch);
    test_Dump_Load_and_Equals(batch);
    test_Compare_Values(batch);
    DECREF(batch);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

