#define C_KINO_TESTINSTREAM
#define C_KINO_INSTREAM
#define C_KINO_FILEWINDOW
#include <stdlib.h>
#include <time.h>

#include "KinoSearch/Util/ToolSet.h"
#include "KinoSearch/Test.h"
#include "KinoSearch/Test/TestUtils.h"
#include "KinoSearch/Test/Store/TestIOChunks.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Store/RAMFile.h"
#include "KinoSearch/Store/RAMFileHandle.h"
#include "KinoSearch/Util/NumberUtils.h"

static void
test_Read_Write_Bytes(TestBatch *batch)
{
    RAMFile    *file      = RAMFile_new(NULL, false);
    OutStream  *outstream = OutStream_open((Obj*)file);
    InStream   *instream;
    char        buf[4];

    OutStream_Write_Bytes(outstream, "foo", 4);
    OutStream_Close(outstream);

    instream = InStream_open((Obj*)file);
    InStream_Read_Bytes(instream, buf, 4);
    ASSERT_TRUE(batch, strcmp(buf, "foo") == 0, "Read_Bytes Write_Bytes");

    DECREF(instream);
    DECREF(outstream);
    DECREF(file);
}

static void
test_Buf(TestBatch *batch)
{
    RAMFile    *file      = RAMFile_new(NULL, false);
    OutStream  *outstream = OutStream_open((Obj*)file);
    InStream   *instream;
    size_t      size = IO_STREAM_BUF_SIZE * 2 + 5;
    u32_t i;
    char       *buf;

    for (i = 0; i < size; i++) {
        OutStream_Write_U8(outstream, 'a');
    }
    OutStream_Close(outstream);

    instream = InStream_open((Obj*)file);
    buf = InStream_Buf(instream, 5);
    ASSERT_INT_EQ(batch, instream->limit - buf, IO_STREAM_BUF_SIZE, 
        "Small request bumped up");

    buf += IO_STREAM_BUF_SIZE - 10; /* 10 bytes left in buffer. */
    InStream_Advance_Buf(instream, buf);

    buf = InStream_Buf(instream, 10);
    ASSERT_INT_EQ(batch, instream->limit - buf, 10, 
        "Exact request doesn't trigger refill");

    buf = InStream_Buf(instream, 11);
    ASSERT_INT_EQ(batch, instream->limit - buf, IO_STREAM_BUF_SIZE, 
        "Requesting over limit triggers refill");

    {
        i64_t  expected = InStream_Length(instream) - InStream_Tell(instream);
        char  *buff     = InStream_Buf(instream, 100000); 
        i64_t  got      = PTR2I64(instream->limit) - PTR2I64(buff);
        ASSERT_TRUE(batch, got == expected,
            "Requests greater than file size get pared down");
    }

    DECREF(instream);
    DECREF(outstream);
    DECREF(file);
}

void
TestIOChunks_run_tests()
{
    TestBatch   *batch     = TestBatch_new(5);

    srand((unsigned int)time((time_t*)NULL));
    TestBatch_Plan(batch);

    test_Read_Write_Bytes(batch);
    test_Buf(batch);
    
    DECREF(batch);
}

/* Copyright 2005-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

