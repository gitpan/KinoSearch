#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#define KINO_WANT_VIRTUALTABLE_VTABLE
#include "KinoSearch/Util/VirtualTable.r"

#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/MemManager.h"

void
VirtualTable_destroy(VirtualTable *self)
{
    UNUSED_VAR(self);
    CONFESS("Attempt to destroy fixed vtable for class '%s'",
        self->_->class_name);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

