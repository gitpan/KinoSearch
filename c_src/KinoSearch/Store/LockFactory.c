#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>
#include <ctype.h>

#define KINO_WANT_LOCKFACTORY_VTABLE
#include "KinoSearch/Store/LockFactory.r"

#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/Lock.r"
#include "KinoSearch/Store/SharedLock.r"

LockFactory*
LockFact_new(Folder *folder, const ByteBuf *agent_id)
{
    CREATE(self, LockFactory, LOCKFACTORY);

    /* assign */
    self->folder       = REFCOUNT_INC(folder);
    self->agent_id     = BB_CLONE(agent_id);

    return self;
}

void
LockFact_destroy(LockFactory *self)
{
    REFCOUNT_DEC(self->folder);
    REFCOUNT_DEC(self->agent_id);
    free(self);
}

Lock*
LockFact_make_lock(LockFactory *self, const ByteBuf *lock_name, i32_t timeout)
{
    return Lock_new(self->folder, lock_name, self->agent_id, timeout);
}

SharedLock*
LockFact_make_shared_lock(LockFactory *self, const ByteBuf *lock_name, 
                          i32_t timeout)
{
    return ShLock_new(self->folder, lock_name, self->agent_id, timeout);
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

