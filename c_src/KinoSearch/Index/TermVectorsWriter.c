#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#include <stdio.h>

#define KINO_WANT_TERMVECTORSWRITER_VTABLE
#include "KinoSearch/Index/TermVectorsWriter.r"

#include "KinoSearch/Analysis/Token.r"
#include "KinoSearch/Analysis/TokenBatch.r"
#include "KinoSearch/InvIndex.r"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/TermVectorsReader.r"
#include "KinoSearch/Util/CClass.r"
#include "KinoSearch/Util/IntMap.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/OutStream.r"

TermVectorsWriter*
TVWriter_new(InvIndex *invindex, SegInfo *seg_info)
{
    ByteBuf *filename = BB_CLONE(seg_info->seg_name);
    CREATE(self, TermVectorsWriter, TERMVECTORSWRITER);

    /* assign */
    REFCOUNT_INC(invindex);
    REFCOUNT_INC(seg_info);
    self->invindex    = invindex;
    self->seg_info    = seg_info;

    /* open outstreams */
    BB_Cat_Str(filename, ".tv", 3);
    self->tv_out  = Folder_Open_OutStream(invindex->folder, filename);
    BB_Cat_Str(filename, "x", 1);
    self->tvx_out = Folder_Open_OutStream(invindex->folder, filename);
    REFCOUNT_DEC(filename);

    return self;
}

ByteBuf*
TVWriter_tv_string(TermVectorsWriter *self, TokenBatch *batch)
{
    char         vint_buf[5];
    char        *last_text = "";
    size_t       last_len = 0;
    i32_t        num_bytes;
    ByteBuf     *tv_string = BB_new(20 + batch->size * 8); /* generous */
    u32_t        num_postings = 0;
    char        *dest;
    Token      **tokens;
    kino_u32_t   freq;
    UNUSED_VAR(self); /* heh. */

    /* leave space for a vint indicating the number of postings. */
    tv_string->len = 5;

    TokenBatch_Reset(batch);
    while ( (tokens = TokenBatch_Next_Cluster(batch, &freq)) != NULL ) {
        Token *token = *tokens;
        i32_t overlap = StrHelp_string_diff(last_text, token->text, 
            last_len, token->len);

        /* track number of postings */
        num_postings += 1;
        
        /* append the string diff to the tv_string */
        num_bytes = OutStream_encode_vint(overlap, vint_buf);
        BB_Cat_Str( tv_string, vint_buf, num_bytes );
        num_bytes = OutStream_encode_vint( (token->len - overlap), vint_buf );
        BB_Cat_Str( tv_string, vint_buf, num_bytes );
        BB_Cat_Str( tv_string, (token->text + overlap), 
            (token->len - overlap) );

        /* save text and text_len for comparison next loop */
        last_text = token->text;
        last_len  = token->len;

        /* append the number of positions for this term */
        num_bytes = OutStream_encode_vint(freq, vint_buf);
        BB_Cat_Str( tv_string, vint_buf, num_bytes );

        do {
            /* add position, start_offset, and end_offset to tv_string */
            num_bytes = OutStream_encode_vint(token->pos, vint_buf);
            BB_Cat_Str( tv_string, vint_buf, num_bytes );
            num_bytes = OutStream_encode_vint(token->start_offset, vint_buf);
            BB_Cat_Str( tv_string, vint_buf, num_bytes );
            num_bytes = OutStream_encode_vint(token->end_offset, vint_buf);
            BB_Cat_Str( tv_string, vint_buf, num_bytes );

        } while (--freq && (token = *++tokens));
    }
    
    /* go back and start the term vector string with the number of postings */
    num_bytes = OutStream_encode_vint(num_postings, vint_buf);
    dest = tv_string->ptr;
    memset(dest, 0x80, (5 - num_bytes)); /* "leading zeroes" */
    dest += (5 - num_bytes);
    memcpy(dest, vint_buf, num_bytes); 

    return tv_string;
}

void
TVWriter_add_segment(TermVectorsWriter *self, TermVectorsReader *tv_reader,
                     IntMap *doc_map, kino_u32_t max_doc)
{
    u32_t      orig;
    ByteBuf   *bb       = BB_new(0);
    OutStream *tv_out   = self->tv_out;
    OutStream *tvx_out  = self->tvx_out;

    /* bail if the supplied segment is empty */
    if (max_doc == 0)
        return;

    for (orig = 0; orig < max_doc; orig++) {
        /* skip deleted docs */
        if (IntMap_Get(doc_map, orig) == -1)
            continue;

        /* write file pointer */
        OutStream_Write_Long( tvx_out, OutStream_STell(tv_out) );
        
        /* copy the raw record */
        TVReader_Read_Record(tv_reader, orig, bb);
        OutStream_Write_Bytes(tv_out, bb->ptr, bb->len);
        bb->len = 0;
    }

    REFCOUNT_DEC(bb);
}

void
TVWriter_finish(TermVectorsWriter *self)
{
    Hash *metadata = Hash_new(0);

    /* close down the output streams */
    OutStream_SClose(self->tv_out);
    OutStream_SClose(self->tvx_out);

    /* generate and store metadata */
    Hash_Store_I64(metadata, "format", 6, (i64_t)TVWRITER_FORMAT);
    SegInfo_Add_Metadata(self->seg_info, "term_vectors", 12, (Obj*)metadata);
    REFCOUNT_DEC(metadata);
}

void
TVWriter_destroy(TermVectorsWriter *self)
{
    REFCOUNT_DEC(self->invindex);
    REFCOUNT_DEC(self->seg_info);
    REFCOUNT_DEC(self->tv_out);
    REFCOUNT_DEC(self->tvx_out);
    free(self);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

