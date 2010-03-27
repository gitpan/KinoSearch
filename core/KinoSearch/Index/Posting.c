#define C_KINO_POSTING
#define C_KINO_POSTINGWRITER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/Posting.h"
#include "KinoSearch/Index/DataWriter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/Posting/RawPosting.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Plan/Schema.h"
#include "KinoSearch/Search/Similarity.h"
#include "KinoSearch/Store/InStream.h"

Posting*
Post_init(Posting *self)
{
    self->doc_id = 0;
    return self;
}

void
Post_set_doc_id(Posting *self, i32_t doc_id) { self->doc_id = doc_id; }
i32_t
Post_get_doc_id(Posting *self) { return self->doc_id; }

PostingWriter*
PostWriter_init(PostingWriter *self, Schema *schema, Snapshot *snapshot,
                Segment *segment, PolyReader *polyreader, i32_t field_num)
{
    DataWriter_init((DataWriter*)self, schema, snapshot, segment,
        polyreader);
    self->field_num = field_num;
    return self;
}

/* Copyright 2007-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */
