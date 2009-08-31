#define C_KINO_SEGREADER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Architecture.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/DeletionsReader.h"
#include "KinoSearch/Index/DocReader.h"
#include "KinoSearch/Index/DocVector.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Search/Matcher.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/I32Array.h"

SegReader*
SegReader_new(Schema *schema, Folder *folder, Snapshot *snapshot, 
              VArray *segments, i32_t seg_tick)
{
    SegReader *self = (SegReader*)VTable_Make_Obj(SEGREADER);
    return SegReader_init(self, schema, folder, snapshot, segments, seg_tick);
}

SegReader*
SegReader_init(SegReader *self, Schema *schema, Folder *folder,
               Snapshot *snapshot, VArray *segments, i32_t seg_tick)
{
    CharBuf *mess;
    Segment *segment;

    IxReader_init((IndexReader*)self, schema, folder, snapshot, segments,
        seg_tick, NULL);
    segment = SegReader_Get_Segment(self);

    self->doc_max    = Seg_Get_Count(segment);
    self->seg_name   = (CharBuf*)INCREF(Seg_Get_Name(segment));
    self->seg_num    = Seg_Get_Number(segment);
    mess = SegReader_Try_Init_Components(self);
    if (mess) {
        /* An error occurred, so clean up self and throw an exception. */
        DECREF(self);
        Err_throw_mess(ERR, mess);
    }
    {
        DeletionsReader *del_reader = (DeletionsReader*)Hash_Fetch(
            self->components, (Obj*)VTable_Get_Name(DELETIONSREADER));
        self->del_count = del_reader ? DelReader_Del_Count(del_reader) : 0;
    }
    return self;
}

void
SegReader_destroy(SegReader *self)
{
    DECREF(self->seg_name);
    SUPER_DESTROY(self, SEGREADER);
}

void
SegReader_register(SegReader *self, const CharBuf *api, DataReader *component)
{
    if (Hash_Fetch(self->components, (Obj*)api)) {
        THROW(ERR, "Interface '%o' already registered");
    }
    ASSERT_IS_A(component, DATAREADER);
    Hash_Store(self->components, (Obj*)api, (Obj*)component);
}

CharBuf*
SegReader_get_seg_name(SegReader *self) { return self->seg_name; }
i32_t
SegReader_get_seg_num(SegReader *self)  { return self->seg_num; }

i32_t
SegReader_del_count(SegReader *self) 
{
    return self->del_count;
}

i32_t
SegReader_doc_max(SegReader *self)
{
    return self->doc_max;
}

i32_t
SegReader_doc_count(SegReader *self)
{
    return self->doc_max - self->del_count;
}

I32Array*
SegReader_offsets(SegReader *self)
{
    i32_t *ints = CALLOCATE(1, i32_t);
    UNUSED_VAR(self);
    return I32Arr_new_steal(ints, 1);
}

VArray*
SegReader_seg_readers(SegReader *self)
{
    VArray *seg_readers = VA_new(1);
    VA_Push(seg_readers, INCREF(self));
    return seg_readers;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

