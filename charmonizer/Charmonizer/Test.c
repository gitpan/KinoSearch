#define CHAZ_USE_SHORT_NAMES

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include "Charmonizer/Test.h"

static void
TestBatch_destroy(TestBatch *batch);

static void
TestBatch_run_test(TestBatch *batch);

void
chaz_Test_init(void) {
	/* unbuffer stdout */
	int check_val = setvbuf(stdout, NULL, _IONBF, 0);
	if (check_val != 0)
		fprintf(stderr, "Failed when trying to unbuffer stdout\n");
}

TestBatch* 
chaz_Test_new_batch(const char *batch_name, unsigned num_tests,
				    TestBatch_test_func_t test_func)
{
    TestBatch *batch = (TestBatch*)malloc(sizeof(TestBatch));

    /* assign */
    batch->num_tests       = num_tests;
	batch->name            = strdup(batch_name);
	batch->test_func       = test_func;
    
    /* initialize */
    batch->test_num        = 0;
    batch->num_passed      = 0;
    batch->num_failed      = 0;
    batch->num_skipped     = 0;
    batch->destroy         = TestBatch_destroy;
	batch->run_test        = TestBatch_run_test;

    return batch;
}

static void
TestBatch_destroy(TestBatch *batch)
{
	free(batch->name);
    free(batch);
}

static void
TestBatch_run_test(TestBatch *batch) 
{
	/* print start */
	printf("===================================\n");
	printf("%s - %u tests to run\n", batch->name, batch->num_tests);
	printf("===================================\n");

	/* run the batch */
	batch->test_func(batch);

	/* print report */
	printf("-------------------------\n");
	printf("Tests:   %d\nPassed:  %d\nFailed:  %d\nSkipped: %d\n\n",
		batch->num_tests, batch->num_passed, batch->num_failed, 
		batch->num_skipped);
}

void
chaz_Test_assert_true(TestBatch *batch, int value, const char *pat, ...)
{
    va_list args;

    /* increment test number */
    batch->test_num++;

    /* test condition and pass or fail */
    if (value) {
        printf("%-4u pass: ", batch->test_num);
        batch->num_passed++;
    }
    else {
        printf("%-4u fail: ", batch->test_num);
        batch->num_failed++;
    }
    
    /* print supplied message */
    va_start(args, pat);
    vprintf(pat, args);
    va_end(args);
    printf("\n");
}

void
chaz_Test_assert_false(TestBatch *batch, int value, const char *pat, ...)
{
    va_list args;

    /* increment test number */
    batch->test_num++;

    /* test condition and pass or fail */
    if (value == 0) {
        printf("%-4u pass: ", batch->test_num);
        batch->num_passed++;
    }
    else {
        printf("%-4u fail: ", batch->test_num);
        batch->num_failed++;
    }
    
    /* print supplied message */
    va_start(args, pat);
    vprintf(pat, args);
    va_end(args);

    printf("\n");
}

void 
chaz_Test_assert_str_eq(TestBatch *batch, const char *expected, 
                        const char *got, const char *pat, ...)
{
    va_list args;
    
    /* increment test number */
    batch->test_num++;
    
    /* test condition and pass or fail */
    if (strcmp(expected, got) == 0) {
        printf("%-4u pass: ", batch->test_num);
        batch->num_passed++;
    }
    else {
        printf("%-4u fail: Expected '%s', got '%s'\n    ", batch->test_num, 
            expected, got);
        batch->num_failed++;
    }
    
    /* print supplied message */
    va_start(args, pat);
    vprintf(pat, args);
    va_end(args);
    printf("\n");
}


void 
chaz_Test_assert_str_neq(TestBatch *batch, const char *expected, 
                         const char *got, const char *pat, ...)
{
    va_list args;
    
    /* increment test number */
    batch->test_num++;
    
    /* test condition and pass or fail */
    if (strcmp(expected, got) != 0) {
        printf("%-4u pass: ", batch->test_num);
        batch->num_passed++;
    }
    else {
        printf("%-4u fail: Expected '%s', got '%s'\n    ", batch->test_num, 
            expected, got);
        batch->num_failed++;
    }
    
    /* print supplied message */
    va_start(args, pat);
    vprintf(pat, args);
    va_end(args);
    printf("\n");
}

void 
chaz_Test_pass(TestBatch *batch, const char *pat, ...)
{
    va_list args;

    /* increment test number */
    batch->test_num++;

    /* indicate pass, update pass counter */
    printf("%-4u pass: ", batch->test_num);
    batch->num_passed++;

    /* print supplied message */
    va_start(args, pat);
    vprintf(pat, args);
    va_end(args);
    printf("\n");
}

void 
chaz_Test_fail(TestBatch *batch, const char *pat, ...)
{
    va_list args;

    /* increment test number */
    batch->test_num++;

    /* indicate failure, update pass counter */
    printf("%-4u fail:\n", batch->test_num);
    batch->num_failed++;

    /* print supplied message */
    va_start(args, pat);
    vprintf(pat, args);
    va_end(args);
    printf("\n");
}

void 
chaz_Test_assert_int_eq(TestBatch *batch, long expected, long got, 
                        const char *pat, ...)
{
    va_list args;

    /* increment test number */
    batch->test_num++;

    if (expected == got) {
        printf("%-4u pass: ", batch->test_num);
        batch->num_passed++;
    }
    else {
        printf("%-4u fail: Expected '%ld', got '%ld'\n    ", batch->test_num, 
            expected, got);
        batch->num_failed++;
    }
    
    /* print supplied message */
    va_start(args, pat);
    vprintf(pat, args);
    va_end(args);
    printf("\n");
}

void 
chaz_Test_assert_float_eq(TestBatch *batch, double expected, 
                          double got, const char *pat, ...)
{
    va_list args;
    double diff = expected/got;

    /* increment test number */
    batch->test_num++;
    
    /* evaluate condition and pass or fail */
    if (diff > 0.00001) {
        printf("%-4u pass: ", batch->test_num);
        batch->num_passed++;
    }
    else {
        printf("%-4u fail: Expected '%f', got '%f'\n    ", batch->test_num, 
            expected, got);
        batch->num_failed++;
    }
    
    /* print supplied message */
    va_start(args, pat);
    vprintf(pat, args);
    va_end(args);
    printf("\n");

}

void
chaz_Test_skip(TestBatch *batch, const char *pat, ...)
{
    va_list args;

    /* increment test number */
    batch->test_num++;

    /* indicate that test is being skipped, update pass counter */
    printf("%-4d skip: ", batch->test_num);
    batch->num_skipped++;

    /* print supplied message */
    va_start(args, pat);
    vprintf(pat, args);
    va_end(args);
    printf("\n");
}

void
chaz_Test_report_skip_remaining(TestBatch *batch, const char *pat, ...)
{
    va_list args;
    unsigned remaining = batch->num_tests - batch->test_num;
    
    /* indicate that tests are being skipped, update skip counter */
    batch->num_skipped += remaining;
    printf("Skipping all %u remaining tests: ", remaining);

    /* print supplied message */
    va_start(args, pat);
    vprintf(pat, args);
    va_end(args);
    printf("\n");
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

