#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_MATCHPOSTING_VTABLE
#include "KinoSearch/Posting/MatchPosting.r"

#include "KinoSearch/Search/Similarity.r"

MatchPosting*
MatchPost_new(Similarity *sim)
{
    CREATE(self, MatchPosting, MATCHPOSTING);
    self->doc_num     = DOC_NUM_SENTINEL;
    self->sim         = REFCOUNT_INC(sim);
    return self;
}

MatchPosting*
MatchPost_dupe(MatchPosting *self, Similarity *sim)
{
    MatchPosting *evil_twin = MatchPost_new(sim);
    evil_twin->doc_num = self->doc_num;
    return evil_twin;
}

void
MatchPost_reset(MatchPosting *self, u32_t doc_num)
{
    self->doc_num  = doc_num;
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

