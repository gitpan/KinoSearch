#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#include <stdio.h>

#define KINO_WANT_TERMVECTORSREADER_VTABLE
#include "KinoSearch/Index/TermVectorsReader.r"

#include "KinoSearch/Schema.r"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Util/CClass.r"
#include "KinoSearch/Util/IntMap.r"


TermVectorsReader*
TVReader_new(Schema *schema, Folder *folder, SegInfo *seg_info)
{
    ByteBuf *filename = BB_CLONE(seg_info->seg_name);
    CREATE(self, TermVectorsReader, TERMVECTORSREADER);

    /* assign */
    REFCOUNT_INC(schema);
    REFCOUNT_INC(folder);
    REFCOUNT_INC(seg_info);
    self->schema      = schema;
    self->folder      = folder;
    self->seg_info    = seg_info;

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
TVReader_read_record(TermVectorsReader *self, i32_t doc_num, ByteBuf *target,
                     IntMap *field_num_map)
{
    u64_t fileptr, next_fileptr;
    u32_t len;
    InStream *tv_in  = self->tv_in;
    InStream *tvx_in = self->tvx_in;

    InStream_SSeek(tvx_in, doc_num * 8);
    fileptr = InStream_Read_Long(tvx_in);
    next_fileptr = (i64_t)InStream_SLength(tvx_in) == (doc_num + 1) * 8
        ? InStream_SLength(tv_in)
        : InStream_Read_Long(tvx_in);
    len     = next_fileptr - fileptr;

    BB_Grow(target, len);

    InStream_SSeek(tv_in, fileptr);

    /* if not remapping, record can be copied whole */
    if (field_num_map == NULL) {
        InStream_Read_Bytes(tv_in, target->ptr, len);
        target->len = len;
    }
    /* we have to remap field numbers */
    else {
        u32_t i;
        u32_t num_fields;
        char vint_bufbuf[10];
        char *vint_buf = vint_bufbuf;
        size_t vint_bytes;

        /* re-encode number of fields */
        num_fields = InStream_Read_VInt(tv_in);
        vint_bytes = OutStream_encode_vint(num_fields, vint_buf);
        BB_Cat_Str(target, vint_buf, vint_bytes);

        /* copy strings */
        for (i = 0; i < num_fields; i++) {
            u32_t field_string_len;
            u32_t field_num     = InStream_Read_VInt(tv_in);
            i32_t new_field_num = IntMap_Get(field_num_map, field_num);

            /* verify and write remapped field num */
            if (new_field_num == -1)
                CONFESS("Don't recognize field_num '%ld'", field_num);
            vint_bytes = OutStream_encode_vint(new_field_num, vint_buf);
            BB_Cat_Str(target, vint_buf, vint_bytes);

            /* write field string length */
            field_string_len = InStream_Read_VInt(tv_in);
            vint_bytes = OutStream_encode_vint(field_string_len, vint_buf);
            BB_Cat_Str(target, vint_buf, vint_bytes);
            
            /* write field string bytes */
            BB_Grow(target, target->len + field_string_len);
            InStream_Read_Bytes(tv_in, BBEND(target), field_string_len);
            target->len += field_string_len;
        }
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

