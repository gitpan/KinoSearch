#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#include <math.h>

#define KINO_WANT_DELDOCS_VTABLE
#include "KinoSearch/Index/DelDocs.r"

#include "KinoSearch/InvIndex.r"
#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Index/TermDocs.r"
#include "KinoSearch/Util/IntMap.r"
#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/OutStream.r"

DelDocs*
DelDocs_new(InvIndex *invindex, SegInfo *seg_info)
{
    Hash *metadata 
        = (Hash*)Hash_Fetch(seg_info->metadata, "deldocs", 7);
    CREATE(self, DelDocs, DELDOCS);

    /* super construct - no initial allocation in case no deletions */
    BitVec_init_base((BitVector*)self, 0);

    /* use either defaults or extracted metadata */
    if (metadata == NULL) {
        self->del_gen = 0;
    }
    else {
        /* check format, get generation */
        if ( Hash_Fetch_I64(metadata, "format", 6) > DELDOCS_FORMAT ) {
            CONFESS("Unsupported deldocs format: %ld", 
                (long)Hash_Fetch_I64(metadata, "format", 6));
        }
        self->del_gen = Hash_Fetch_I64(metadata, "del_gen", 7);
        self->count = Hash_Fetch_I64(metadata, "num_deletions", 13);
    }

    /* assign */
    REFCOUNT_INC(invindex);
    REFCOUNT_INC(seg_info);
    self->invindex  = invindex;
    self->seg_info  = seg_info;

    /* read file if generation so indicates */
    if (self->del_gen)
        DelDocs_Read_Deldocs(self);
    
    return self;
}

void
DelDocs_read_deldocs(DelDocs *self)
{
    ByteBuf ext = { &BYTEBUF, 0, ".del", 4, 0 };
    ByteBuf *filename = IxFileNames_filename_from_gen(
        self->seg_info->seg_name, self->del_gen, &ext);

    /* bail if del_gen is 0 (and therefore filename is null) */
    if (filename == NULL) {
        return;
    }
    else if (!Folder_File_Exists(self->invindex->folder, filename)) {
        CONFESS("file '%s' is not available", filename->ptr);
    }
    else {
        InStream *instream 
            = Folder_Open_InStream(self->invindex->folder, filename);
        size_t byte_size = InStream_SLength(instream);

        /* allocate space */
        self->capacity   = byte_size * 8;
        free(self->bits);
        self->bits = MALLOCATE(byte_size, u8_t);

        /* read in bit vector */
        InStream_Read_Bytes(instream, (char*)self->bits, byte_size);
        InStream_SClose(instream);

        /* clean up */
        REFCOUNT_DEC(filename);
        REFCOUNT_DEC(instream);
    }
}

void
DelDocs_write_deldocs(DelDocs *self)
{
    Hash *metadata = Hash_new(0);
    size_t byte_size = ceil( self->seg_info->doc_count / 8.0 );
    ByteBuf ext = { &BYTEBUF, 0, ".del", 4, 0 };
    ByteBuf *filename;
    OutStream *outstream;
    
    /* increment generation, get an outstream; */
    self->del_gen++;
    filename = IxFileNames_filename_from_gen( self->seg_info->seg_name, 
        self->del_gen, &ext); 
    outstream = Folder_Open_OutStream(self->invindex->folder, filename);
    REFCOUNT_DEC(filename);

    /* make sure that we have 1 bit for each doc in segment */
    DelDocs_Grow(self, self->seg_info->doc_count);

    /* write deletions data and clean up */
    OutStream_Write_Bytes(outstream, (char*)self->bits, byte_size);
    OutStream_SClose(outstream);
    REFCOUNT_DEC(outstream);

    /* store metadata in seg_info */
    Hash_Store_I64(metadata, "del_gen", 7, (i64_t)self->del_gen);
    Hash_Store_I64(metadata, "format", 6, (i64_t)DELDOCS_FORMAT);
    Hash_Store_I64(metadata, "num_deletions", 13, (i64_t)DelDocs_Count(self));
    SegInfo_Add_Metadata(self->seg_info, "deldocs", 7, (Obj*)metadata);
    REFCOUNT_DEC(metadata);
}

IntMap*
DelDocs_generate_doc_map(DelDocs *self, i32_t offset) 
{
    i32_t  max = self->seg_info->doc_count;
    i32_t *doc_map = MALLOCATE(max, i32_t);
    i32_t  new_doc_num;
    i32_t  i;

    /* -1 for a deleted doc, a new number otherwise */
    for (i = 0, new_doc_num = 0; i < max; i++) {
        if (DelDocs_Get(self, i))
            doc_map[i] = -1;
        else
            doc_map[i] = offset + new_doc_num++;
    }
    
    return IntMap_new(doc_map, max);
}

void
DelDocs_delete_by_term_docs(DelDocs* self, TermDocs* term_docs) 
{
    /* iterate through term docs, marking each doc returned as deleted */
    while (TermDocs_Next(term_docs)) {
        i32_t doc = TermDocs_Get_Doc(term_docs);
        DelDocs_Set(self, doc);
    }
}

void
DelDocs_destroy(DelDocs *self)
{
    REFCOUNT_DEC(self->invindex);
    REFCOUNT_DEC(self->seg_info);
    BitVec_destroy((BitVector*)self);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

