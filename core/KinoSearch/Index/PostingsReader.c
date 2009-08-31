#define C_KINO_POSTINGSREADER
#define C_KINO_POLYPOSTINGSREADER
#define C_KINO_DEFAULTPOSTINGSREADER
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/PostingsReader.h"
#include "KinoSearch/Architecture.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/Schema.h"
#include "KinoSearch/Index/LexiconReader.h"
#include "KinoSearch/Index/PolyPostingList.h"
#include "KinoSearch/Index/PostingsWriter.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/SegPostingList.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/I32Array.h"

PostingsReader*
PostReader_init(PostingsReader *self, Schema *schema, Folder *folder, 
                Snapshot *snapshot, VArray *segments, i32_t seg_tick)
{
    DataReader_init((DataReader*)self, schema, folder, snapshot, segments,
        seg_tick);
    ABSTRACT_CLASS_CHECK(self, POSTINGSREADER);
    return self;
}

PostingsReader*
PostReader_aggregator(PostingsReader *self, VArray *readers, 
                      I32Array *offsets)
{
    UNUSED_VAR(self);
    return (PostingsReader*)PolyPostReader_new(readers, offsets);
}

PolyPostingsReader*
PolyPostReader_new(VArray *readers, I32Array *offsets)
{
    PolyPostingsReader *self 
        = (PolyPostingsReader*)VTable_Make_Obj(POLYPOSTINGSREADER);
    return PolyPostReader_init(self, readers, offsets);
}

PolyPostingsReader*
PolyPostReader_init(PolyPostingsReader *self, VArray *readers, 
                   I32Array *offsets)
{
    u32_t i, max;
    Schema *schema = NULL;
    for (i = 0, max = VA_Get_Size(readers); i < max; i++) {
        PostingsReader *reader = (PostingsReader*)VA_Fetch(readers, i);
        ASSERT_IS_A(reader, POSTINGSREADER);
        if (!schema) { schema = PostReader_Get_Schema(reader); }
    }
    PostReader_init((PostingsReader*)self, schema, NULL, NULL, NULL, -1);
    self->readers = (VArray*)INCREF(readers);
    self->offsets = (I32Array*)INCREF(offsets);
    return self;
}

void
PolyPostReader_close(PolyPostingsReader *self)
{
    if (self->readers) {
        u32_t i, max;
        for (i = 0, max = VA_Get_Size(self->readers); i < max; i++) {
            PostingsReader *sub_reader 
                = (PostingsReader*)VA_Fetch(self->readers, i);
            if (sub_reader) { PostReader_Close(sub_reader); }
        }
        DECREF(self->readers);
        DECREF(self->offsets);
        self->readers = NULL;
        self->offsets = NULL;
    }
}

void
PolyPostReader_destroy(PolyPostingsReader *self)
{
    DECREF(self->readers);
    DECREF(self->offsets);
    SUPER_DESTROY(self, POLYPOSTINGSREADER);
}

PostingList*
PolyPostReader_posting_list(PolyPostingsReader *self, const CharBuf *field, 
                            Obj *term)
{
    Schema *schema = PolyPostReader_Get_Schema(self);
    FieldType *type = schema ? Schema_Fetch_Type(schema, field) : NULL;
    if (type && FType_Indexed(type)) {
        PolyPostingList *plist = PolyPList_new(field, self->readers,
            self->offsets);
        if (!PolyPList_Get_Num_Subs(plist)) {
            DECREF(plist);
            return NULL;
        }
        if (term) { PolyPList_Seek(plist, term); }
        return (PostingList*)plist;
    }
    return NULL;
}

DefaultPostingsReader*
DefPostReader_new(Schema *schema, Folder *folder, Snapshot *snapshot,
                  VArray *segments, i32_t seg_tick, LexiconReader *lex_reader)
{
    DefaultPostingsReader *self 
        = (DefaultPostingsReader*)VTable_Make_Obj(DEFAULTPOSTINGSREADER);
    return DefPostReader_init(self, schema, folder, snapshot, segments, 
        seg_tick, lex_reader);
}

DefaultPostingsReader*
DefPostReader_init(DefaultPostingsReader *self, Schema *schema, 
                   Folder *folder, Snapshot *snapshot, VArray *segments,
                   i32_t seg_tick, LexiconReader *lex_reader)
{
    Segment      *segment;
    PostReader_init((PostingsReader*)self, schema, folder, snapshot, segments,
        seg_tick);
    segment = DefPostReader_Get_Segment(self);

    /* Derive. */
    self->lex_reader = (LexiconReader*)INCREF(lex_reader);

    /* Check format. */
    {
        Hash *my_meta = (Hash*)Seg_Fetch_Metadata_Str(segment, "postings", 8);
        if (!my_meta) { 
            my_meta = (Hash*)Seg_Fetch_Metadata_Str(segment, 
                "posting_list", 12);
        }

        if (my_meta) {
            Obj *format = Hash_Fetch_Str(my_meta, "format", 6);
            if (!format) { THROW(ERR, "Missing 'format' var"); }
            else {
                if (Obj_To_I64(format) != PostWriter_current_file_format) {
                    THROW(ERR, "Unsupported postings format: %i64", 
                        Obj_To_I64(format));
                }
            }
        }
    }
    
    return self;
}

void
DefPostReader_close(DefaultPostingsReader *self)
{
    if (self->lex_reader) {
        LexReader_Close(self->lex_reader);
        DECREF(self->lex_reader);
        self->lex_reader = NULL;
    }
}

void
DefPostReader_destroy(DefaultPostingsReader *self)
{
    DECREF(self->lex_reader);
    SUPER_DESTROY(self, DEFAULTPOSTINGSREADER);
}

SegPostingList*
DefPostReader_posting_list(DefaultPostingsReader *self, 
                           const CharBuf *field, Obj *target)
{
    FieldType *type  = Schema_Fetch_Type(self->schema, field);

    /* Only return an object if we've got an indexed field. */
    if (type != NULL && FType_Indexed(type)) {
        SegPostingList *plist = SegPList_new((PostingsReader*)self, field);
        if (target) SegPList_Seek(plist, target);
        return plist;
    }
    else {
        return NULL;
    }
}

LexiconReader*
DefPostReader_get_lex_reader(DefaultPostingsReader *self) 
    { return self->lex_reader; }

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

