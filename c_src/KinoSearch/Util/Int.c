#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_INT_VTABLE
#include "KinoSearch/Util/Int.r"

Int*
Int_new(i64_t value)
{
    CREATE(self, Int, INT);
    self->value = value;
    return self;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

