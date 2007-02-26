#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/IndexFileNames.h"

ByteBuf*
IxFileNames_latest_gen(VArray *list, const ByteBuf *base, const ByteBuf *ext)
{
    u32_t i;
    ByteBuf *retval = NULL;
    i32_t generation = -1;
    size_t min_len = base->len + ext->len + 2; /* underscore and a digit */

    /* iterate over the files in this folder */
    for (i = 0; i < list->size; i++) {
        ByteBuf *candidate = (ByteBuf*)VA_Fetch(list, i);
        char *cand_ext;

        if (candidate == NULL)
            continue;
        if (!OBJ_IS_A(candidate, BYTEBUF)) {
            CONFESS("Object is a %s, not a ByteBuf, so can't match %s and %s",
                base->ptr, ext->ptr);
        }

        cand_ext = BBEND(candidate) - ext->len;

        if (   candidate->len < min_len
            || strncmp(base->ptr, candidate->ptr, base->len) != 0
            || strncmp(ext->ptr, cand_ext, ext->len) != 0
        ) {
            /* skip if file doesn't begin with base or end with ext */
            continue;
        }
        else {
            /* extract the generation */
            char *ptr = candidate->ptr + base->len + 1;
            i32_t this_gen = strtol(ptr, NULL, 36);
            
            /* if this is the most recent so far, remember the filename */
            if (this_gen > generation) {
                generation = this_gen;
                retval     = candidate;
            }
        }
    }

    return retval;
}

ByteBuf*
IxFileNames_filename_from_gen(const ByteBuf *base, i32_t gen, 
                              const ByteBuf *ext)
{
    /* negative generation is sentinel */
    if (gen == -1) {
        return NULL;
    }
    else {
        ByteBuf *filename = BB_new(base->len + ext->len + 15);
        ByteBuf *base36_gen = StrHelp_to_base36(gen);

        /* concat components */
        BB_copy_bb(filename, base);
        BB_Cat_Str(filename, "_", 1);
        BB_Cat_BB(filename, base36_gen);
        BB_Cat_BB(filename, ext);
        REFCOUNT_DEC(base36_gen);

        return filename;
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

