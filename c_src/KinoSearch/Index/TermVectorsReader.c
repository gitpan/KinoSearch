#include "KinoSearch/Util/ToolSet.h"

#include <stdio.h>

#define KINO_WANT_TERMVECTORSREADER_VTABLE
#include "KinoSearch/Index/TermVectorsReader.r"

#include "KinoSearch/Schema.r"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Util/Native.r"
#include "KinoSearch/Util/IntMap.r"


TermVectorsReader*
TVReader_new(Schema *schema, Folder *folder, SegInfo *seg_info)
{
    ByteBuf *filename = BB_CLONE(seg_info->seg_name);
    CREATE(self, TermVectorsReader, TERMVECTORSREADER);

    /* assign */
    self->schema      = REFCOUNT_INC(schema);
    self->folder      = REFCOUNT_INC(folder);
    self->seg_info    = REFCOUNT_INC(seg_info);

    /* open instreams */
    BB_Cat_Str(filename, ".tv", 3);
    self->tv_in  = Folder_Open_InStream(folder, filename);
    BB_Cat_Str(filename, "x", 1);
    self->tvx_in = Folder_Open_InStream(folder, filename);
    REFCOUNT_DEC(filename);

    return self;
}

void
TVReader_destroy(TermVectorsReader *self)
{
    REFCOUNT_DEC(self->schema);
    REFCOUNT_DEC(self->folder);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->tv_in);
    REFCOUNT_DEC(self->tvx_in);
    free(self);
}

void
TVReader_read_record(TermVectorsReader *self, i32_t doc_num, ByteBuf *target)
{
    u64_t filepos;
    u32_t len;
    InStream *tv_in  = self->tv_in;
    InStream *tvx_in = self->tvx_in;

    InStream_SSeek(tvx_in, doc_num * 16);
    filepos = InStream_Read_Long(tvx_in);
    len     = InStream_Read_Long(tvx_in);

    BB_GROW(target, len);

    /* copy the whole record */
    InStream_SSeek(tv_in, filepos);
    InStream_Read_Bytes(tv_in, target->ptr, len);
    target->len = len;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

