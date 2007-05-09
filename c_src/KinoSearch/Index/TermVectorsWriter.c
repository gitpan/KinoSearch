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
#include "KinoSearch/Store/InStream.r"

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
    BB_Cat_Str(filename, "xtemp", 5);
    self->tvx_out = Folder_Open_OutStream(invindex->folder, filename);
    REFCOUNT_DEC(filename);

    return self;
}

ByteBuf*
TVWriter_tv_string(TermVectorsWriter *self, TokenBatch *batch)
{
    char        *last_text = "";
    size_t       last_len = 0;
    ByteBuf     *tv_string = BB_new(20 + batch->size * 8); /* generous */
    u32_t        num_postings = 0;
    char        *dest;
    Token      **tokens;
    u32_t        freq;
    UNUSED_VAR(self); /* heh. */

    /* leave space for a vint indicating the number of postings. */
    tv_string->len = VINT_MAX_BYTES;

    TokenBatch_Reset(batch);
    while ( (tokens = TokenBatch_Next_Cluster(batch, &freq)) != NULL ) {
        Token *token = *tokens;
        i32_t overlap = StrHelp_string_diff(last_text, token->text, 
            last_len, token->len);
        char *ptr;
        size_t new_size = tv_string->len
                          + VINT_MAX_BYTES     /* overlap */
                          + VINT_MAX_BYTES     /* length of string diff */
                          + (token->len - overlap) /* diff char data */
                          + VINT_MAX_BYTES               /* num prox */
                          + (VINT_MAX_BYTES * freq * 3); /* pos data */

        /* allocate for worst-case scenario */
        BB_GROW(tv_string, new_size);
        ptr = BBEND(tv_string);

        /* track number of postings */
        num_postings += 1;
        
        /* append the string diff to the tv_string */
        ENCODE_VINT(overlap, ptr);
        ENCODE_VINT( (token->len - overlap), ptr);
        memcpy(ptr, (token->text + overlap), (token->len - overlap));
        ptr += token->len - overlap;

        /* save text and text_len for comparison next loop */
        last_text = token->text;
        last_len  = token->len;

        /* append the number of positions for this term */
        ENCODE_VINT(freq, ptr);

        do {
            /* add position, start_offset, and end_offset to tv_string */
            ENCODE_VINT(token->pos, ptr);
            ENCODE_VINT(token->start_offset, ptr);
            ENCODE_VINT(token->end_offset, ptr);

        } while (--freq && (token = *++tokens));

        /* set new length */
        tv_string->len = ptr - tv_string->ptr; 
    }
    
    /* go back and start the term vector string with the number of postings */
    dest = tv_string->ptr;
    ENCODE_FULL_VINT(num_postings, dest);

    return tv_string;
}

void
TVWriter_add_segment(TermVectorsWriter *self, TermVectorsReader *tv_reader,
                     IntMap *doc_map, u32_t max_doc)
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

        /* write length of entry */
        OutStream_Write_Long(tvx_out, bb->len);

        bb->len = 0;
    }

    REFCOUNT_DEC(bb);
}

void
TVWriter_finish(TermVectorsWriter *self, IntMap *doc_remap)
{
    Folder *folder = self->invindex->folder;
    Hash *metadata = Hash_new(0);
    ByteBuf *tvxtemp_filename = BB_CLONE(self->seg_info->seg_name);
    ByteBuf *tvx_filename     = BB_CLONE(self->seg_info->seg_name);

    /* build filenames */
    BB_Cat_Str(tvxtemp_filename, ".tvxtemp", 8);
    BB_Cat_Str(tvx_filename, ".tvx", 4);

    /* close down the output streams */
    OutStream_SClose(self->tv_out);
    OutStream_SClose(self->tvx_out);

    if (doc_remap == NULL) {
        Folder_Rename_File(folder, tvxtemp_filename, tvx_filename);
    }
    /* remap document numbers */
    else {
        OutStream *final     = Folder_Open_OutStream(folder, tvx_filename);
        InStream  *orig      = Folder_Open_InStream(folder, tvxtemp_filename);
        u32_t max_doc        = InStream_SLength(orig) / 16;
        u64_t *const entries = MALLOCATE(max_doc * 2, u64_t);
        u32_t i;

        for (i = 0; i < max_doc; i++) {
            /* read bytes into memory, remapping as we go */
            const u32_t new_doc = IntMap_Get(doc_remap, i);
            char *const buf = (char*)entries + new_doc * 16;
            InStream_Read_Bytes(orig, buf, 16);
        }

        /* blast out remapped info */
        OutStream_Write_Bytes(final, (char*)entries, max_doc * 16);

        /* clean up */
        InStream_SClose(orig);
        OutStream_SClose(final);
        REFCOUNT_DEC(orig);
        REFCOUNT_DEC(final);
        free(entries);
    }

    /* generate and store metadata */
    Hash_Store_I64(metadata, "format", 6, (i64_t)TVWRITER_FORMAT);
    SegInfo_Add_Metadata(self->seg_info, "term_vectors", 12, (Obj*)metadata);

    /* clean up */
    REFCOUNT_DEC(metadata);
    REFCOUNT_DEC(tvxtemp_filename);
    REFCOUNT_DEC(tvx_filename);
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

