#define CHAZ_USE_SHORT_NAMES

#include "charmony.h"
#include <string.h>
#include "Charmonizer/Test.h"
#include "Charmonizer/Test/AllTests.h"

TestBatch*
chaz_TFuncMacro_prepare()
{
    return Test_new_batch("FuncMacro", 4, chaz_TFuncMacro_run);
}

static INLINE char* inline_function()
{
    return "inline works";
}

void
chaz_TFuncMacro_run(TestBatch *batch)
{

#ifdef HAS_FUNC_MACRO
    ASSERT_STR_EQ(batch, FUNC_MACRO, "chaz_TFuncMacro_run", 
        "FUNC_MACRO");
#endif

#ifdef HAS_ISO_FUNC_MACRO
    ASSERT_STR_EQ(batch, __func__, "chaz_TFuncMacro_run",
        "HAS_ISO_FUNC_MACRO");
#endif

#ifdef HAS_GNUC_FUNC_MACRO
    ASSERT_STR_EQ(batch, __FUNCTION__, "chaz_TFuncMacro_run", 
        "HAS_GNUC_FUNC_MACRO");
#endif

    PASS(batch, inline_function());
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

