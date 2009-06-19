#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Posting.h"
#include "KinoSearch/Store/InStream.h"
#include "KinoSearch/Search/Similarity.h"

Posting*
Post_init(Posting *self)
{
    self->doc_id = 0;
    return self;
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

