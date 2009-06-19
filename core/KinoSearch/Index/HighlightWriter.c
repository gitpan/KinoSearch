#include "KinoSearch/Util/ToolSet.h"

#include <stdio.h>

#include "KinoSearch/Index/HighlightWriter.h"
#include "KinoSearch/Analysis/Token.h"
#include "KinoSearch/Analysis/Inversion.h"
#include "KinoSearch/FieldType.h"
#include "KinoSearch/FieldType/FullTextType.h"
#include "KinoSearch/Index/HighlightReader.h"
#include "KinoSearch/Index/Inverter.h"
#include "KinoSearch/Index/PolyReader.h"
#include "KinoSearch/Index/SegReader.h"
#include "KinoSearch/Index/Segment.h"
#include "KinoSearch/Index/Snapshot.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Util/ByteBuf.h"
#include "KinoSearch/Util/I32Array.h"

static OutStream*
S_lazy_init(HighlightWriter *self);

i32_t HLWriter_current_file_format = 1;

HighlightWriter*
HLWriter_new(Snapshot *snapshot, Segment *segment, PolyReader *polyreader)
{
    HighlightWriter *self 
        = (HighlightWriter*)VTable_Make_Obj(&HIGHLIGHTWRITER);
    return HLWriter_init(self, snapshot, segment, polyreader);
}

HighlightWriter*
HLWriter_init(HighlightWriter *self, Snapshot *snapshot, Segment *segment,
              PolyReader *polyreader)
{
    DataWriter_init((DataWriter*)self, snapshot, segment, polyreader);
    return self;
}

void
HLWriter_destroy(HighlightWriter *self)
{
    DECREF(self->dat_out);
    DECREF(self->ix_out);
    SUPER_DESTROY(self, HIGHLIGHTWRITER);
}

static OutStream*
S_lazy_init(HighlightWriter *self)
{
    if (!self->dat_out) {
        Segment  *segment  = self->segment;
        Folder   *folder   = self->folder;
        Snapshot *snapshot = HLWriter_Get_Snapshot(self);
        CharBuf  *seg_name = Seg_Get_Name(segment);
        CharBuf  *ix_file  = CB_newf("%o/highlight.ix", seg_name);
        CharBuf  *dat_file = CB_newf("%o/highlight.dat", seg_name);

        /* Open outstreams. */
        Snapshot_Add_Entry(snapshot, ix_file);
        Snapshot_Add_Entry(snapshot, dat_file);
        self->ix_out  = Folder_Open_Out(folder, ix_file);
        self->dat_out = Folder_Open_Out(folder, dat_file);
        if (!self->ix_out)  { THROW("Can't open %o", ix_file); }
        if (!self->dat_out) { THROW("Can't open %o", dat_file); }
        DECREF(ix_file);
        DECREF(dat_file);

        /* Go past invalid doc 0. */
        OutStream_Write_U64(self->ix_out, 0);
    }

    return self->dat_out;
}

void
HLWriter_add_inverted_doc(HighlightWriter *self, Inverter *inverter, 
                          i32_t doc_id)
{
    OutStream *dat_out = S_lazy_init(self);
    OutStream *ix_out  = self->ix_out;
    i64_t      filepos = OutStream_Tell(dat_out);
    u32_t num_highlightable = 0;
    i32_t expected = (i32_t)(OutStream_Tell(ix_out) / 8);

    /* Verify doc id. */
    if (doc_id != expected)
        THROW("Expected doc id %i32 but got %i32", expected, doc_id);

    /* Write index data. */
    OutStream_Write_U64(ix_out, filepos);

    /* Count, then write number of highlightable fields. */
    Inverter_Iter_Init(inverter);
    while (Inverter_Next(inverter)) {
        FieldType *type = Inverter_Get_Type(inverter);
        if (   OBJ_IS_A(type, FULLTEXTTYPE) 
            && FullTextType_Highlightable(type)
        ) {
            num_highlightable++;
        }
    }
    OutStream_Write_C32(dat_out, num_highlightable);

    Inverter_Iter_Init(inverter);
    while (Inverter_Next(inverter)) {
        FieldType *type = Inverter_Get_Type(inverter);
        if (   OBJ_IS_A(type, FULLTEXTTYPE) 
            && FullTextType_Highlightable(type)
        ) {
            CharBuf   *field     = Inverter_Get_Field_Name(inverter);
            Inversion *inversion = Inverter_Get_Inversion(inverter);
            ByteBuf   *tv_buf    = HLWriter_TV_Buf(self, inversion);
            CB_Serialize(field, dat_out);
            BB_Serialize(tv_buf, dat_out);
            DECREF(tv_buf);
        }
    }
}

ByteBuf*
HLWriter_tv_buf(HighlightWriter *self, Inversion *inversion)
{
    char        *last_text = "";
    size_t       last_len = 0;
    ByteBuf     *tv_buf = BB_new(20 + inversion->size * 8); /* generous */
    u32_t        num_postings = 0;
    char        *dest;
    Token      **tokens;
    u32_t        freq;
    UNUSED_VAR(self); /* heh. */

    /* Leave space for a c32 indicating the number of postings. */
    BB_Set_Size(tv_buf, C32_MAX_BYTES);

    Inversion_Reset(inversion);
    while ( (tokens = Inversion_Next_Cluster(inversion, &freq)) != NULL ) {
        Token *token = *tokens;
        i32_t overlap = StrHelp_string_diff(last_text, token->text, 
            last_len, token->len);
        char *ptr;
        size_t new_size =   BB_Get_Size(tv_buf)
                          + C32_MAX_BYTES      /* overlap */
                          + C32_MAX_BYTES      /* length of string diff */
                          + (token->len - overlap) /* diff char data */
                          + C32_MAX_BYTES                /* num prox */
                          + (C32_MAX_BYTES * freq * 3);  /* pos data */

        /* Allocate for worst-case scenario. */
        BB_Grow(tv_buf, new_size);
        ptr = BBEND(tv_buf);

        /* Track number of postings. */
        num_postings += 1;
        
        /* Append the string diff to the tv_buf. */
        Math_encode_c32(overlap, &ptr);
        Math_encode_c32( (token->len - overlap), &ptr);
        memcpy(ptr, (token->text + overlap), (token->len - overlap));
        ptr += token->len - overlap;

        /* Save text and text_len for comparison next loop. */
        last_text = token->text;
        last_len  = token->len;

        /* Append the number of positions for this term. */
        Math_encode_c32(freq, &ptr);

        do {
            /* Add position, start_offset, and end_offset to tv_buf. */
            Math_encode_c32(token->pos, &ptr);
            Math_encode_c32(token->start_offset, &ptr);
            Math_encode_c32(token->end_offset, &ptr);

        } while (--freq && (token = *++tokens));

        /* Set new byte length. */
        BB_Set_Size(tv_buf, ptr - tv_buf->ptr); 
    }
    
    /* Go back and start the term vector string with the number of postings. */
    dest = tv_buf->ptr;
    Math_encode_padded_c32(num_postings, &dest);

    return tv_buf;
}

void
HLWriter_add_segment(HighlightWriter *self, SegReader *reader, 
                     I32Array *doc_map)
{
    i32_t doc_max = SegReader_Doc_Max(reader);

    if (doc_max == 0) {
        /* Bail if the supplied segment is empty. */
        return;
    }
    else {
        DefaultHighlightReader *hl_reader = (DefaultHighlightReader*)
            ASSERT_IS_A(SegReader_Obtain(reader, HIGHLIGHTREADER.name),
            DEFAULTHIGHLIGHTREADER);
        OutStream *dat_out = S_lazy_init(self);
        OutStream *ix_out  = self->ix_out;
        i32_t      orig;
        ByteBuf   *bb = BB_new(0);

        for (orig = 1; orig <= doc_max; orig++) {
            /* Skip deleted docs. */
            if (doc_map && !I32Arr_Get(doc_map, orig))
                continue;

            /* Write file pointer. */
            OutStream_Write_U64( ix_out, OutStream_Tell(dat_out) );
            
            /* Copy the raw record. */
            DefHLReader_Read_Record(hl_reader, orig, bb);
            OutStream_Write_Bytes(dat_out, bb->ptr, bb->size);

            bb->size = 0;
        }
        DECREF(bb);
    }
}

void
HLWriter_delete_segment(HighlightWriter *self, SegReader *reader)
{
    CharBuf  *merged_seg_name = Seg_Get_Name(SegReader_Get_Segment(reader));
    Snapshot *snapshot = HLWriter_Get_Snapshot(self);
    CharBuf  *ix_file  = CB_newf("%o/highlight.ix", merged_seg_name);
    CharBuf  *dat_file = CB_newf("%o/highlight.dat", merged_seg_name);
    Snapshot_Delete_Entry(snapshot, ix_file);
    Snapshot_Delete_Entry(snapshot, dat_file);
    DECREF(ix_file);
    DECREF(dat_file);
}

void
HLWriter_finish(HighlightWriter *self)
{
    if (self->dat_out) {
        /* Write one final file pointer, so that we can derive the length of
         * the last record. */
        i64_t end = OutStream_Tell(self->dat_out);
        OutStream_Write_U64(self->ix_out, end);
        
        /* Close down the output streams. */
        OutStream_Close(self->dat_out);
        OutStream_Close(self->ix_out);
        Seg_Store_Metadata_Str(self->segment, "highlight", 9, 
            (Obj*)HLWriter_Metadata(self));
    }
}

i32_t
HLWriter_format(HighlightWriter *self)
{
    UNUSED_VAR(self);
    return HLWriter_current_file_format;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

