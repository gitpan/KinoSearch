#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Posting.h"
#include "KinoSearch/Index/DataWriter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Posting/RawPosting.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Search/Similarity.h"

Posting*
Post_init(Posting *self)
{
    self->doc_id = 0;
    return self;
}

void
Post_set_doc_id(Posting *self, i32_t doc_id) { self->doc_id = doc_id; }

PostingStreamer*
PostStreamer_init(PostingStreamer *self, DataWriter *writer, i32_t field_num)
{
    Schema     *schema     = DataWriter_Get_Schema(writer);
    Snapshot   *snapshot   = DataWriter_Get_Snapshot(writer);
    Segment    *segment    = DataWriter_Get_Segment(writer);
    PolyReader *polyreader = DataWriter_Get_PolyReader(writer);
    DataWriter_init((DataWriter*)self, schema, snapshot, segment,
        polyreader);
    self->field_num = field_num;
    return self;
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

