#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_BBSORTEXRUN_VTABLE
#include "KinoSearch/Util/BBSortExRun.r"

#include "KinoSearch/Store/InStream.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Util/BBSortEx.r"

BBSortExRun*
BBSortExRun_new(Obj **elems, u32_t num_elems) 
{
    CREATE(self, BBSortExRun, BBSORTEXRUN);
    
    /* init */
    SortExRun_init_base((SortExRun*)self, BBSortEx_compare_bbs);
    self->mem_thresh   = 0;
    self->instream     = NULL;
    self->start        = 0;
    self->end          = 0;

    /* take posession of cache elems */
    self->cache = MALLOCATE(num_elems, Obj*);
    memcpy(self->cache, elems, num_elems * sizeof(Obj*));
    self->cache_max = num_elems;
    self->cache_cap = num_elems;

    return self;
}

void
BBSortExRun_flush(BBSortExRun *self, OutStream *outstream)
{
    Obj       **cache   = self->cache;
    Obj **const limit   = cache + self->cache_max;

    /* sanity check */
    if (self->end != 0)
        CONFESS("Can't flush twice");

    /* mark start of run */
    self->start   = OutStream_STell(outstream);
    
    /* write items to file */
    for ( ; cache < limit; cache++) {
        ByteBuf *const bb = (ByteBuf*)*cache;
        OutStream_Write_VInt(outstream, bb->len);
        OutStream_Write_Bytes(outstream, bb->ptr, bb->len);
    }

    /* release elements */
    BBSortExRun_Clear_Cache(self);
    free(self->cache);
    self->cache     = NULL;
    self->cache_cap = 0;

    /* mark end of run */
    self->end = OutStream_STell(outstream);
}

void
BBSortExRun_flip(BBSortExRun *self, InStream *instream, u32_t mem_thresh)
{
    if (self->instream != NULL)
        CONFESS("Can't call BBSortexRun_Flip more than once");
    if (mem_thresh == 0)
        CONFESS("mem_thresh cannot be 0");
    self->instream   = (InStream*)InStream_Clone(instream);
    InStream_SSeek(self->instream, self->start);
    self->mem_thresh = mem_thresh;
}

u32_t
BBSortExRun_refill(BBSortExRun *self)
{
    InStream   *instream        = self->instream;
    const u32_t mem_thresh      = self->mem_thresh;
    u64_t       end             = self->end;
    u32_t       bytes_read      = 0;
    u32_t       num_elems       = 0; /* number of items recovered */
    u32_t       len;
    ByteBuf    *bb;

    if (self->instream == NULL)
        return 0;

    /* make sure cache is empty */
    if (self->cache_max - self->cache_tick > 0) {
        CONFESS("Refill called but cache contains %u items",
            self->cache_max - self->cache_tick);
    }
    BBSortExRun_Clear_Cache(self);

    while (1) {
        /* bail if we've read everything in this run */
        if (InStream_STell(instream) >= end) {
            /* make sure we haven't read too much */
            if (InStream_STell(instream) > end) {
                unsigned long pos = (unsigned long)InStream_STell(instream);
                CONFESS("read past end of run: %lu %lu", pos, 
                    (unsigned long)end);
            }
            break;
        }

        /* bail if we've hit the ceiling for this run's cache */
        if (bytes_read >= mem_thresh)
            break;

        /* retrieve and decode len; allocate ByteBuf and recover string */
        len = InStream_Read_VInt(instream);
        bb  = BB_new(len);
        InStream_Read_Bytes(instream, bb->ptr, len);
        bb->len = len;
        *BBEND(bb) = '\0';

        /* add to the run's cache */
        if (num_elems == self->cache_cap) {
            BBSortExRun_Grow_Cache(self, num_elems);
        }
        self->cache[ num_elems ] = (Obj*)bb;

        /* track how much we've read so far */
        num_elems++;
        bytes_read += len + 1;
    }

    /* reset the cache array position and length; remember file pos */
    self->cache_max   = num_elems;
    self->cache_tick  = 0;

    return num_elems;
}

void
BBSortExRun_destroy(BBSortExRun *self) 
{
    REFCOUNT_DEC(self->instream);
    BBSortExRun_Clear_Cache(self);
    REFCOUNT_DEC(self->context);
    free(self->cache);
    free(self);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

