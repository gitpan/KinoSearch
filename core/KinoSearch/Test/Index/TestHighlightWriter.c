#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Index/TestHighlightWriter.h"
#include "KinoSearch/Index/HighlightWriter.h"

void
TestHLWriter_run_tests()
{
    TestBatch *batch = Test_new_batch("TestHighlightWriter", 1, NULL);
    PLAN(batch);
    PASS(batch, "Placeholder");
    batch->destroy(batch);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

