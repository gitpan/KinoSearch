#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>
#include <ctype.h>

#include "KinoSearch/Store/LockFactory.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/Lock.h"
#include "KinoSearch/Store/SharedLock.h"

LockFactory*
LockFact_new(Folder *folder, const CharBuf *agent_id)
{
    LockFactory *self = (LockFactory*)VTable_Make_Obj(&LOCKFACTORY);
    return LockFact_init(self, folder, agent_id);
}

LockFactory*
LockFact_init(LockFactory *self, Folder *folder, const CharBuf *agent_id)
{
    self->folder       = (Folder*)INCREF(folder);
    self->agent_id     = CB_Clone(agent_id);
    return self;
}

void
LockFact_destroy(LockFactory *self)
{
    DECREF(self->folder);
    DECREF(self->agent_id);
    FREE_OBJ(self);
}

Lock*
LockFact_make_lock(LockFactory *self, const CharBuf *lock_name, 
                   i32_t timeout)
{
    return Lock_new(self->folder, lock_name, self->agent_id, timeout);
}

SharedLock*
LockFact_make_shared_lock(LockFactory *self, const CharBuf *lock_name, 
                          i32_t timeout)
{
    return ShLock_new(self->folder, lock_name, self->agent_id, timeout);
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

