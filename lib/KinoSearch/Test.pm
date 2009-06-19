use KinoSearch;

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Test

void
run_tests(package)
    char *package;
PPCODE:
{
    /* KinoSearch::Analysis */
    if (strEQ(package, "TestCaseFolder")) {
        kino_TestCaseFolder_run_tests();
    }
    else if (strEQ(package, "TestPolyAnalyzer")) {
        kino_TestPolyAnalyzer_run_tests();
    }
    else if (strEQ(package, "TestStopalizer")) {
        kino_TestStopalizer_run_tests();
    }
    else if (strEQ(package, "TestStemmer")) {
        kino_TestStemmer_run_tests();
    }
    else if (strEQ(package, "TestTokenizer")) {
        kino_TestTokenizer_run_tests();
    }
    /* KinoSearch::FieldType */
    else if (strEQ(package, "TestBlobType")) {
        kino_TestBlobType_run_tests();
    }
    else if (strEQ(package, "TestFullTextType")) {
        kino_TestFullTextType_run_tests();
    }
    /* KinoSearch::Obj */
    else if (strEQ(package, "TestObj")) {
        kino_TestObj_run_tests();
    }
    /* KinoSearch::QueryParser */
    else if (strEQ(package, "TestQueryParserSyntax")) {
    }
    else if (strEQ(package, "TestQueryParserLogic")) {
        kino_TestQPLogic_run_tests();
    }
    /* KinoSearch::Index */
    else if (strEQ(package, "TestHighlightWriter")) {
        kino_TestHLWriter_run_tests();
    }
    else if (strEQ(package, "TestDocWriter")) {
        kino_TestDocWriter_run_tests();
    }
    else if (strEQ(package, "TestPostingsWriter")) {
        kino_TestPostWriter_run_tests();
    }
    else if (strEQ(package, "TestSegWriter")) {
        kino_TestSegWriter_run_tests();
    }
    /* KinoSearch::Schema */
    else if (strEQ(package, "TestSchema")) {
        kino_TestSchema_run_tests();
    }
    /* KinoSearch::Search */
    else if (strEQ(package, "TestANDQuery")) {
        kino_TestANDQuery_run_tests();
    }
    else if (strEQ(package, "TestLeafQuery")) {
        kino_TestLeafQuery_run_tests();
    }
    else if (strEQ(package, "TestMatchAllQuery")) {
        kino_TestMatchAllQuery_run_tests();
    }
    else if (strEQ(package, "TestNoMatchQuery")) {
        kino_TestNoMatchQuery_run_tests();
    }
    else if (strEQ(package, "TestNOTQuery")) {
        kino_TestNOTQuery_run_tests();
    }
    else if (strEQ(package, "TestORQuery")) {
        kino_TestORQuery_run_tests();
    }
    else if (strEQ(package, "TestPhraseQuery")) {
        kino_TestPhraseQuery_run_tests();
    }
    else if (strEQ(package, "TestSeriesMatcher")) {
        kino_TestSeriesMatcher_run_tests();
    }
    else if (strEQ(package, "TestRangeQuery")) {
        kino_TestRangeQuery_run_tests();
    }
    else if (strEQ(package, "TestReqOptQuery")) {
        kino_TestReqOptQuery_run_tests();
    }
    else if (strEQ(package, "TestTermQuery")) {
        kino_TestTermQuery_run_tests();
    }
    /* KinoSearch::Store */
    else if (strEQ(package, "TestInStream")) {
        kino_TestInStream_run_tests();
    }
    /* KinoSearch::Util */
    else if (strEQ(package, "TestBitVector")) {
        kino_TestBitVector_run_tests();
    }
    else if (strEQ(package, "TestHash")) {
        kino_TestHash_run_tests();
    }
    else if (strEQ(package, "TestIntArrays")) {
        kino_TestIntArrays_run_tests();
    }
    else if (strEQ(package, "TestPriorityQueue")) {
        kino_TestPriQ_run_tests();
    }
    else if (strEQ(package, "TestMemoryPool")) {
        kino_TestMemPool_run_tests();
    }
    else if (strEQ(package, "TestVArray")) {
        kino_TestVArray_run_tests();
    }
    else {
        THROW("Unknown test id: %s", package);
    }
}

MODULE = KinoSearch   PACKAGE = KinoSearch::Test::TestQueryParserSyntax

void
run_tests(index);
    kino_Folder *index;
PPCODE:
    kino_TestQPSyntax_run_tests(index);

MODULE = KinoSearch   PACKAGE = KinoSearch::Test::TestCharmonizer

void
run_tests(which)
    char *which;
PPCODE:
{
    chaz_TestBatch *batch = NULL;
    chaz_Test_init();

    if (strcmp(which, "dirmanip") == 0) {
        batch = chaz_TDirManip_prepare();
    }
    else if (strcmp(which, "integers") == 0) {
        batch = chaz_TIntegers_prepare();
    }
    else if (strcmp(which, "func_macro") == 0) {
        batch = chaz_TFuncMacro_prepare();
    }
    else if (strcmp(which, "headers") == 0) {
        batch = chaz_THeaders_prepare();
    }
    else if (strcmp(which, "large_files") == 0) {
        batch = chaz_TLargeFiles_prepare();
    }
    else if (strcmp(which, "unused_vars") == 0) {
        batch = chaz_TUnusedVars_prepare();
    }
    else if (strcmp(which, "variadic_macros") == 0) {
        batch = chaz_TVariadicMacros_prepare();
    }
    else {
        THROW("Unknown test identifier: '%s'", which);
    }

    batch->run_test(batch);
    batch->destroy(batch);
}

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

