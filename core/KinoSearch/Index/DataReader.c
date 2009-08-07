#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/DataReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Store/Folder.h"

DataReader*
DataReader_init(DataReader *self, Schema *schema, Folder *folder, 
                Snapshot *snapshot, VArray *segments, i32_t seg_tick)
{
    self->schema   = schema   ? (Schema*)INCREF(schema)     : NULL;
    self->folder   = folder   ? (Folder*)INCREF(folder)     : NULL;
    self->snapshot = snapshot ? (Snapshot*)INCREF(snapshot) : NULL;
    self->segments = segments ? (VArray*)INCREF(segments)   : NULL;
    self->seg_tick = seg_tick;
    if (seg_tick != -1) {
        if (!segments) {
            THROW(ERR, "No segments array provided, but seg_tick is %i32",
                seg_tick);
        }
        else {
            Segment *segment = (Segment*)VA_Fetch(segments, seg_tick);
            if (!segment) {
                THROW(ERR, "No segment at seg_tick %i32", seg_tick);
            }
            self->segment = (Segment*)INCREF(segment);
        }
    }
    else {
        self->segment = NULL;
    }

    ABSTRACT_CLASS_CHECK(self, DATAREADER);
    return self;
}

void
DataReader_destroy(DataReader *self)
{
    DECREF(self->schema);
    DECREF(self->folder);
    DECREF(self->snapshot);
    DECREF(self->segments);
    DECREF(self->segment);
    FREE_OBJ(self);
}

Schema*
DataReader_get_schema(DataReader *self) 
    { return self->schema; }
Folder*
DataReader_get_folder(DataReader *self) 
    { return self->folder; }
Snapshot*
DataReader_get_snapshot(DataReader *self) 
    { return self->snapshot; }
VArray*
DataReader_get_segments(DataReader *self) 
    { return self->segments; }
i32_t
DataReader_get_seg_tick(DataReader *self)
    { return self->seg_tick; }
Segment*
DataReader_get_segment(DataReader *self) 
    { return self->segment; }

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

