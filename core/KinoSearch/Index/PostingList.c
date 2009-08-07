#include <string.h>

#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/PostingList.h"
#include "KinoSearch/Posting.h"
#include "KinoSearch/Index/Lexicon.h"
#include "KinoSearch/Util/MemManager.h"

PostingList*
PList_init(PostingList *self)
{
    ABSTRACT_CLASS_CHECK(self, POSTINGLIST);
    return self;
}

i32_t
PList_advance(PostingList *self, i32_t target) 
{
    while (1) {
        i32_t doc_id = PList_Next(self);
        if (doc_id == 0 || doc_id >= target)
            return doc_id; 
    }
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

