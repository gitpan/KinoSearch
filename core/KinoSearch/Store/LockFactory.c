#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>
#include <ctype.h>

#include "KinoSearch/Store/LockFactory.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/Lock.h"
#include "KinoSearch/Store/SharedLock.h"

LockFactory*
LockFact_new(Folder *folder, const CharBuf *hostname)
{
    LockFactory *self = (LockFactory*)VTable_Make_Obj(LOCKFACTORY);
    return LockFact_init(self, folder, hostname);
}

LockFactory*
LockFact_init(LockFactory *self, Folder *folder, const CharBuf *hostname)
{
    self->folder    = (Folder*)INCREF(folder);
    self->hostname  = CB_Clone(hostname);
    return self;
}

void
LockFact_destroy(LockFactory *self)
{
    DECREF(self->folder);
    DECREF(self->hostname);
    SUPER_DESTROY(self, LOCKFACTORY);
}

Lock*
LockFact_make_lock(LockFactory *self, const CharBuf *name, i32_t timeout, 
                   i32_t interval)
{
    return (Lock*)LFLock_new(self->folder, name, self->hostname, timeout, 
        interval);
}

Lock*
LockFact_make_shared_lock(LockFactory *self, const CharBuf *name, 
                          i32_t timeout, i32_t interval)
{
    return (Lock*)ShLock_new(self->folder, name, self->hostname, timeout, 
        interval);
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

