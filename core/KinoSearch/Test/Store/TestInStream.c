#define C_KINO_TESTINSTREAM
#define C_KINO_INSTREAM
#define C_KINO_FILEWINDOW
#include "KinoSearch/Util/ToolSet.h"

#define CHAZ_USE_SHORT_NAMES
#include "Charmonizer/Test.h"

#include "KinoSearch/Test/Store/TestInStream.h"
#include "KinoSearch/Test/TestSchema.h"
#include "KinoSearch/Store/FileDes.h"
#include "KinoSearch/Store/FileWindow.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Store/RAMFolder.h"

void
TestInStream_run_tests()
{
    TestBatch   *batch     = Test_new_batch("TestInStream", 11, NULL);
    RAMFolder   *folder    = RAMFolder_new(NULL);
    CharBuf     *filename  = CB_new(0);
    OutStream   *outstream;
    InStream    *instream;
    char         scratch[5];
    i32_t i;

    PLAN(batch);

    CB_Cat_Str(filename, "foo", 3);
    outstream = Folder_Open_Out(folder, filename);
    if (!outstream) { THROW(ERR, "Can't open %o", filename); }
    for (i = 0; i < 1023; i++) {
        OutStream_Write_U8(outstream, 'x');
    }
    OutStream_Write_U8(outstream, 'y');
    OutStream_Write_U8(outstream, 'z');
    OutStream_Close(outstream);

    instream = Folder_Open_In(folder, filename);
    if (!instream) { THROW(ERR, "Can't open %o", filename); }
    InStream_Refill(instream);
    ASSERT_INT_EQ(batch, instream->limit - instream->buf, IO_STREAM_BUF_SIZE,
        "Refill");
    ASSERT_INT_EQ(batch, (long)InStream_Tell(instream), 0, 
        "Correct file pos after standing-start Refill()");
    DECREF(instream);

    instream = Folder_Open_In(folder, filename);
    if (!instream) { THROW(ERR, "Can't open %o", filename); }
    InStream_Fill(instream, 30);
    ASSERT_INT_EQ(batch, instream->limit - instream->buf, 30, "Fill()");
    ASSERT_INT_EQ(batch, (long)InStream_Tell(instream), 0, 
        "Correct file pos after standing-start Fill()");
    DECREF(instream);

    instream = Folder_Open_In(folder, filename);
    if (!instream) { THROW(ERR, "Can't open %o", filename); }
    InStream_Read_Bytes(instream, scratch, 5);
    ASSERT_INT_EQ(batch, instream->limit - instream->buf, 
        IO_STREAM_BUF_SIZE - 5, "small read triggers refill");
    DECREF(instream);

    instream = Folder_Open_In(folder, filename);
    if (!instream) { THROW(ERR, "Can't open %o", filename); }
    ASSERT_INT_EQ(batch, InStream_Read_U8(instream), 'x', "Read_U8");
    InStream_Seek(instream, 1023);
    ASSERT_INT_EQ(batch, (long)instream->window->offset, 0, 
        "no unnecessary refill on Seek");
    ASSERT_INT_EQ(batch, (long)InStream_Tell(instream), 1023, "Seek/Tell");
    ASSERT_INT_EQ(batch, InStream_Read_U8(instream), 'y', 
        "correct data after in-buffer Seek()");
    ASSERT_INT_EQ(batch, InStream_Read_U8(instream), 'z', "automatic Refill");
    ASSERT_TRUE(batch, (instream->window->offset != 0), "refilled");
    
    DECREF(instream);
    DECREF(outstream);
    DECREF(folder);
    DECREF(filename);
    batch->destroy(batch);
}

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

