#define C_KINO_INDEXFILENAMES
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Util/IndexFileNames.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Util/StringHelper.h"
#include "KinoSearch/Util/Json.h"

CharBuf*
IxFileNames_latest_snapshot(Folder *folder)
{
    VArray *file_list = Folder_List(folder);
    CharBuf *retval   = NULL;
    i32_t latest_gen = 0;
    u32_t i, max;

    for (i = 0, max = VA_Get_Size(file_list); i < max; i++) {
        CharBuf *filename = (CharBuf*)VA_Fetch(file_list, i);
        if (   CB_Starts_With_Str(filename, "snapshot_", 9)
            && CB_Ends_With_Str(filename, ".json", 5)
        ) {
            i32_t gen = IxFileNames_extract_gen(filename);
            if (gen > latest_gen) {
                latest_gen = gen;
                if (!retval) retval = CB_Clone(filename);
                else CB_Mimic(retval, (Obj*)filename);
            }
        }
    }
    DECREF(file_list);

    return retval;
}

i32_t
IxFileNames_extract_gen(const CharBuf *name)
{
    ZombieCharBuf num_string = ZCB_make(name);

    /* Advance past first underscore.  Bail if we run out of string or if we
     * encounter a NULL. */
    while (1) {
        u32_t code_point = ZCB_Nip_One(&num_string);
        if (code_point == 0) { return 0; }
        else if (code_point == '_') { break; }
    }

    return (i32_t)ZCB_BaseX_To_I64(&num_string, 36);
}

int
IxFileNames_compare_gen(const void *va, const void *vb)
{
    CharBuf *a = *(CharBuf**)va;
    CharBuf *b = *(CharBuf**)vb;
    return IxFileNames_extract_gen(a) - IxFileNames_extract_gen(b);
}


/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

