#define C_KINO_TESTSCHEMA
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/TestArchitecture.h"
#include "KinoSearch/Test/TestSchema.h"
#include "KinoSearch/Analysis/CaseFolder.h"
#include "KinoSearch/Analysis/Tokenizer.h"
#include "KinoSearch/Architecture.h"
#include "KinoSearch/FieldType/FullTextType.h"

TestSchema*
TestSchema_new()
{
    TestSchema *self = (TestSchema*)VTable_Make_Obj(TESTSCHEMA);
    return TestSchema_init(self);
}

static ZombieCharBuf content = ZCB_LITERAL("content");

TestSchema*
TestSchema_init(TestSchema *self)
{
    Tokenizer *tokenizer = Tokenizer_new(NULL);
    FullTextType *type = FullTextType_new((Analyzer*)tokenizer);

    Schema_init((Schema*)self);
    FullTextType_Set_Highlightable(type, true);
    Schema_Spec_Field(self, (CharBuf*)&content, (FieldType*)type);
    DECREF(type);
    DECREF(tokenizer);

    return self;
}

Architecture*
TestSchema_architecture(TestSchema *self)
{
    UNUSED_VAR(self);
    return (Architecture*)TestArch_new();
}

static void
test_Equals(TestBatch *batch)
{
    TestSchema *schema = TestSchema_new();
    TestSchema *arch_differs = TestSchema_new();
    TestSchema *spec_differs = TestSchema_new();
    FullTextType  *type 
        = (FullTextType*)Schema_Fetch_Type(spec_differs, (CharBuf*)&content);
    CaseFolder *case_folder = CaseFolder_new();


    ASSERT_TRUE(batch, TestSchema_Equals(schema, (Obj*)schema), "Equals");

    FullTextType_Set_Analyzer(type, (Analyzer*)case_folder);
    ASSERT_FALSE(batch, TestSchema_Equals(schema, (Obj*)spec_differs), 
        "Equals spoiled by differing FieldType");

    DECREF(arch_differs->arch);
    arch_differs->arch = Arch_new();
    ASSERT_FALSE(batch, TestSchema_Equals(schema, (Obj*)arch_differs), 
        "Equals spoiled by differing Architecture");

    DECREF(schema);
    DECREF(arch_differs);
    DECREF(spec_differs);
    DECREF(case_folder);
}

static void
test_Dump_and_Load(TestBatch *batch)
{
    TestSchema *schema = TestSchema_new();
    Obj *dump = (Obj*)TestSchema_Dump(schema);
    TestSchema *loaded = (TestSchema*)Obj_Load(dump, dump);

    ASSERT_FALSE(batch, TestSchema_Equals(schema, (Obj*)loaded), 
        "Dump => Load round trip");

    DECREF(schema);
    DECREF(dump);
    DECREF(loaded);
}

void
TestSchema_run_tests()
{
    TestBatch *batch = Test_new_batch("TestDocWriter", 4, NULL);
    PLAN(batch);
    test_Equals(batch);
    test_Dump_and_Load(batch);
    batch->destroy(batch);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

