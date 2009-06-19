#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Test/Util/BBSortExRun.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Test/Util/BBSortEx.h"
#include "KinoSearch/Util/ByteBuf.h"

BBSortExRun*
BBSortExRun_new(VArray *external) 
{
    BBSortExRun *self = (BBSortExRun*)VTable_Make_Obj(&BBSORTEXRUN);
    return BBSortExRun_init(self, external);
}

BBSortExRun*
BBSortExRun_init(BBSortExRun *self, VArray *external)
{
    /* Init. */
    SortExRun_init((SortExRun*)self);
    self->mem_thresh    = 0;
    self->mem_consumed  = 0;
    self->external_tick = 0;

    /* Take posession of cache elems. */
    self->external = (VArray*)INCREF(external);

    return self;
}

void
BBSortExRun_destroy(BBSortExRun *self) 
{
    DECREF(self->external);
    SUPER_DESTROY(self, BBSORTEXRUN);
}

void
BBSortExRun_set_mem_thresh(BBSortExRun *self, u32_t mem_thresh)
{
    self->mem_thresh = mem_thresh;
}

int
BBSortExRun_compare(BBSortExRun *self, Obj **a, Obj **b)
{
    UNUSED_VAR(self);
    return BB_compare( (ByteBuf**)a, (ByteBuf**)b );
}

Obj*
BBSortExRun_read_elem(BBSortExRun *self)
{
    if (self->mem_consumed >= self->mem_thresh) {
        self->mem_consumed = 0;
        return NULL;
    }
    else if (self->external_tick >= VA_Get_Size(self->external)) {
        return NULL;
    }
    else {
        ByteBuf *retval 
            = (ByteBuf*)VA_Fetch(self->external, self->external_tick);
        self->external_tick++;
        /* Should be + sizeof(ByteBuf), but that's ok. */
        self->mem_consumed += BB_Get_Size(retval); 
        return INCREF(retval);
    }
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

