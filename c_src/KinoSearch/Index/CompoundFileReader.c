#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_COMPOUNDFILEREADER_VTABLE
#include "KinoSearch/Index/CompoundFileReader.r"

#include "KinoSearch/InvIndex.r"
#include "KinoSearch/Index/IndexFileNames.h"
#include "KinoSearch/Index/SegInfo.r"
#include "KinoSearch/Store/InStream.r"

CompoundFileReader*
CFReader_new(InvIndex *invindex, SegInfo *seg_info)
{
    ByteBuf *filename = BB_CLONE(seg_info->seg_name);
    Hash *metadata 
        = (Hash*)SegInfo_Extract_Metadata(seg_info, "compound_file", 13);
    CREATE(self, CompoundFileReader, COMPOUNDFILEREADER);

    /* check format */
    if (Hash_Fetch_I64(metadata, "format", 6) > COMPOUND_FILE_FORMAT) {
        CONFESS("Unsupported compound file format: %ld", 
            (long)Hash_Fetch_I64(metadata, "format", 6));
    }

    /* assign */
    REFCOUNT_INC(invindex);
    REFCOUNT_INC(seg_info);
    self->invindex  = invindex;
    self->seg_info  = seg_info;

    /* retrieve entries */
    self->entries = (Hash*)Hash_Fetch(metadata, "sub_files", 9);
    if (self->entries == NULL)
        CONFESS("Failed to extract 'sub_files' from compound_file metadata");
    REFCOUNT_INC(self->entries);

    /* open an instream which we'll clone over and over */
    BB_Cat_Str(filename, ".cf", 3);
    self->instream = Folder_Open_InStream(invindex->folder, filename);
    REFCOUNT_DEC(filename);

    return self;
}

void
CFReader_destroy(CompoundFileReader *self)
{
    REFCOUNT_DEC(self->invindex);
    REFCOUNT_DEC(self->instream);
    REFCOUNT_DEC(self->entries);
    REFCOUNT_DEC(self->seg_info);
    free(self);
}

static void
retrieve_offset_and_len(CompoundFileReader *self, const ByteBuf *filename,
                        u64_t *offset, u64_t *len)
{
    Hash *entry = (Hash*)Hash_Fetch_BB(self->entries, filename);
    if (entry == NULL)
        CONFESS("Couldn't find entry for '%s'", filename->ptr);
    
    *offset = Hash_Fetch_I64(entry, "offset", 6);
    *len    = Hash_Fetch_I64(entry, "length", 6);
}

InStream*
CFReader_open_instream(CompoundFileReader *self, const ByteBuf *filename)
{
    u64_t len;
    u64_t offset;

    retrieve_offset_and_len(self, filename, &offset, &len);

    return InStream_Reopen(self->instream, filename, offset, len);
}

ByteBuf*
CFReader_slurp_file(CompoundFileReader *self, const ByteBuf *filename)
{
    u64_t len;
    u64_t offset;
    ByteBuf *retval;

    retrieve_offset_and_len(self, filename, &offset, &len);
    retval = BB_new(len);
    InStream_SSeek(self->instream, offset);
    InStream_Read_Bytes(self->instream, retval->ptr, len);
    retval->len = len;
    
    return retval;
}

bool_t
CFReader_file_exists(CompoundFileReader *self, const ByteBuf *filename)
{
    Hash *entry = (Hash*)Hash_Fetch_BB(self->entries, filename);
    if (entry == NULL)
        return false;
    else 
        return true;
}

VArray*
CFReader_list(CompoundFileReader *self) {
    return Hash_keys(self->entries);
}

void
CFReader_close_f(CompoundFileReader *self)
{
    InStream_SClose(self->instream);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

