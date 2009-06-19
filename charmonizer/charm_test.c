#include <stdio.h>
#include <string.h>
#include "Charmonizer/Test.h"
#include "Charmonizer/Test/AllTests.h"

int main(int argc, char *argv[])
{
    if (argc < 2) {
        fprintf(stderr, "usage: charm_test TEST_ID");
        return 1;
    }

    chaz_AllTests_init();
    if (strcmp(argv[1], "integers") == 0) {
        chaz_TestBatch *batch = chaz_TIntegers_prepare();
        batch->run_test(batch);
    }
    else if (strcmp(argv[1], "func_macro") == 0) {
        chaz_TestBatch *batch = chaz_TFuncMacro_prepare();
        batch->run_test(batch);
    }
    else if (strcmp(argv[1], "headers") == 0) {
        chaz_TestBatch *batch = chaz_THeaders_prepare();
        batch->run_test(batch);
    }
    else if (strcmp(argv[1], "large_files") == 0) {
        chaz_TestBatch *batch = chaz_TLargeFiles_prepare();
        batch->run_test(batch);
    }
    else if (strcmp(argv[1], "unused_vars") == 0) {
        chaz_TestBatch *batch = chaz_TUnusedVars_prepare();
        batch->run_test(batch);
    }
    else if (strcmp(argv[1], "variadic_macros") == 0) {
        chaz_TestBatch *batch = chaz_TVariadicMacros_prepare();
        batch->run_test(batch);
    }

    return 0;
}

