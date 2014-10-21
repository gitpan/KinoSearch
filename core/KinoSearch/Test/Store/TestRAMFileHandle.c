#include <string.h>

#define C_KINO_TESTINSTREAM
#define C_KINO_INSTREAM
#define C_KINO_FILEWINDOW
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test.h"
#include "KinoSearch/Test/Store/TestRAMFileHandle.h"
#include "KinoSearch/Store/RAMFileHandle.h"
#include "KinoSearch/Store/FileWindow.h"
#include "KinoSearch/Store/RAMFile.h"

static void
test_open(TestBatch *batch)
{
    RAMFileHandle *fh;

    Err_set_error(NULL);
    fh = RAMFH_open(NULL, FH_WRITE_ONLY, NULL);
    ASSERT_TRUE(batch, fh == NULL, 
        "open() without a RAMFile or FH_CREATE returns NULL");
    ASSERT_TRUE(batch, Err_get_error() != NULL,
        "open() without a RAMFile or FH_CREATE sets error");
}

static void
test_Read_Write(TestBatch *batch)
{
    RAMFile *file = RAMFile_new(NULL, false);
    RAMFileHandle *fh = RAMFH_open(NULL, FH_WRITE_ONLY, file);
    const char *foo = "foo";
    const char *bar = "bar";
    char buffer[12];
    char *buf = buffer;

    ASSERT_TRUE(batch, CB_Equals_Str(RAMFH_Get_Path(fh), "", 0), 
        "NULL arg as filepath yields empty string");

    ASSERT_TRUE(batch, RAMFH_Write(fh, foo, 3), "Write returns success");
    ASSERT_TRUE(batch, RAMFH_Length(fh) == 3, "Length after one Write");
    ASSERT_TRUE(batch, RAMFH_Write(fh, bar, 3), "Write returns success");
    ASSERT_TRUE(batch, RAMFH_Length(fh) == 6, "Length after two Writes");

    Err_set_error(NULL);
    ASSERT_FALSE(batch, RAMFH_Read(fh, buf, 0, 2), 
        "Reading from a write-only handle returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Reading from a write-only handle sets error");

    // Reopen for reading. 
    DECREF(fh);
    fh = RAMFH_open(NULL, FH_READ_ONLY, file);
    ASSERT_TRUE(batch, RAMFile_Read_Only(file), 
        "FH_READ_ONLY propagates to RAMFile's read_only property");

    ASSERT_TRUE(batch, RAMFH_Read(fh, buf, 0, 6), "Read returns success");
    ASSERT_TRUE(batch, strncmp(buf, "foobar", 6) == 0, "Read/Write");
    ASSERT_TRUE(batch, RAMFH_Read(fh, buf, 2, 3), "Read returns success");
    ASSERT_TRUE(batch, strncmp(buf, "oba", 3) == 0, "Read with offset");

    Err_set_error(NULL);
    ASSERT_FALSE(batch, RAMFH_Read(fh, buf, -1, 4),
        "Read() with a negative offset returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Read() with a negative offset sets error");

    Err_set_error(NULL);
    ASSERT_FALSE(batch, RAMFH_Read(fh, buf, 6, 1),
        "Read() past EOF returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Read() past EOF sets error");

    Err_set_error(NULL);
    ASSERT_FALSE(batch, RAMFH_Write(fh, foo, 3), 
        "Writing to a read-only handle returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Writing to a read-only handle sets error");

    DECREF(fh);
    DECREF(file);
}

static void
test_Grow_and_Get_File(TestBatch *batch)
{
    RAMFileHandle *fh = RAMFH_open(NULL, FH_WRITE_ONLY | FH_CREATE, NULL);
    RAMFile *ram_file = RAMFH_Get_File(fh);
    ByteBuf *contents = RAMFile_Get_Contents(ram_file);

    RAMFH_Grow(fh, 100);
    ASSERT_TRUE(batch, BB_Get_Capacity(contents) >= 100, "Grow");

    DECREF(fh);
}

static void
test_Close(TestBatch *batch)
{
    RAMFileHandle *fh = RAMFH_open(NULL, FH_WRITE_ONLY | FH_CREATE, NULL);
    ASSERT_TRUE(batch, RAMFH_Close(fh), "Close returns true");
    DECREF(fh);
}

static void
test_Window(TestBatch *batch)
{
    RAMFile *file = RAMFile_new(NULL, false);
    RAMFileHandle *fh = RAMFH_open(NULL, FH_WRITE_ONLY, file);
    FileWindow *window = FileWindow_new();
    uint32_t i;

    for (i = 0; i < 1024; i++) {
        RAMFH_Write(fh, "foo ", 4);
    }
    RAMFH_Close(fh);

    // Reopen for reading. 
    DECREF(fh);
    fh = RAMFH_open(NULL, FH_READ_ONLY, file);

    Err_set_error(NULL);
    ASSERT_FALSE(batch, RAMFH_Window(fh, window, -1, 4),
        "Window() with a negative offset returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Window() with a negative offset sets error");

    Err_set_error(NULL);
    ASSERT_FALSE(batch, RAMFH_Window(fh, window, 4000, 1000),
        "Window() past EOF returns false");
    ASSERT_TRUE(batch, Err_get_error() != NULL, 
        "Window() past EOF sets error");

    ASSERT_TRUE(batch, RAMFH_Window(fh, window, 1021, 2), 
        "Window() returns true");
    ASSERT_TRUE(batch, strncmp(window->buf, "oo", 2) == 0, "Window()");

    ASSERT_TRUE(batch, RAMFH_Release_Window(fh, window), 
        "Release_Window() returns true");
    ASSERT_TRUE(batch, window->buf == NULL, "Release_Window() resets buf");
    ASSERT_TRUE(batch, window->offset == 0, "Release_Window() resets offset");
    ASSERT_TRUE(batch, window->len == 0, "Release_Window() resets len");

    DECREF(window);
    DECREF(fh);
    DECREF(file);
}

void
TestRAMFH_run_tests()
{
    TestBatch *batch = TestBatch_new(32);

    TestBatch_Plan(batch);
    test_open(batch);
    test_Read_Write(batch);
    test_Grow_and_Get_File(batch);
    test_Close(batch);
    test_Window(batch);

    DECREF(batch);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

