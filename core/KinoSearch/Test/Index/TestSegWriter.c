#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Index/TestSegWriter.h"
#include "KinoSearch/Index/SegWriter.h"

void
TestSegWriter_run_tests()
{
    TestBatch *batch = Test_new_batch("TestSegWriter", 1, NULL);
    PLAN(batch);
    PASS(batch, "placeholder");
    batch->destroy(batch);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
