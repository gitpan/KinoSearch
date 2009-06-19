#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>
#include <ctype.h>

#include "KinoSearch/Store/SharedLock.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/OutStream.h"

SharedLock*
ShLock_new(Folder *folder, const CharBuf *lock_name, const CharBuf *agent_id, 
           i32_t timeout)
{
    SharedLock *self = (SharedLock*)VTable_Make_Obj(&SHAREDLOCK);
    return ShLock_init(self, folder, lock_name, agent_id, timeout);
}

SharedLock*
ShLock_init(SharedLock *self, Folder *folder, const CharBuf *lock_name, 
            const CharBuf *agent_id, i32_t timeout)
{
    Lock_init((Lock*)self, folder, lock_name, agent_id, timeout);

    /* Override. */
    DECREF(self->filename);
    self->filename = (CharBuf*)INCREF(&EMPTY);

    return self;
}

bool_t
ShLock_do_obtain(SharedLock *self)
{
    u32_t i = 0;
    ShLock_do_obtain_t super_do_obtain 
        = (ShLock_do_obtain_t)SUPER_METHOD(&SHAREDLOCK, ShLock, Do_Obtain);

    /* EMPTY filename indicates whether this particular instance is locked. */
    if (   self->filename != (CharBuf*)&EMPTY 
        && Folder_Exists(self->folder, self->filename)
    ) {
        /* Don't allow double obtain. */
        return false;
    }

    DECREF(self->filename);
    self->filename = CB_new(CB_Get_Size(self->lock_name) + 10);
    do {
        CB_setf(self->filename, "%o-%u32.lock", self->lock_name, ++i);
    } while ( Folder_Exists(self->folder, self->filename) );

    return super_do_obtain(self);
}

void
ShLock_release(SharedLock *self)
{
    if (self->filename != (CharBuf*)&EMPTY) {
        ShLock_release_t super_release
            = (ShLock_release_t)SUPER_METHOD(&SHAREDLOCK, ShLock, Release);
        super_release(self);

        /* Empty out filename. */
        DECREF(self->filename);
        self->filename = (CharBuf*)INCREF(&EMPTY);
    }
}

bool_t
ShLock_is_locked(SharedLock *self)
{
    VArray *files = Folder_List(self->folder);
    u32_t i, max;
    bool_t locked = false;
    
    for (i = 0, max = VA_Get_Size(files); i < max; i++) {
        CharBuf *filename = (CharBuf*)VA_Fetch(files, i);

        /* Translation: $locked = 1 if $filename =~ /$lock_name-\d+\.lock$/ */
        if (CB_Starts_With(filename, self->lock_name)) {
            ZombieCharBuf temp = ZCB_make(filename);
            ZCB_Nip(&temp, CB_Length(self->lock_name));
            if (ZCB_Nip_One(&temp) == '-') {
                while (isdigit(ZCB_Code_Point_At(&temp, 0))) {
                    ZCB_Nip_One(&temp);
                }
                if (CB_Equals_Str(&temp, ".lock", 5)) {
                    locked = true;
                }
            }
        }
    }
    DECREF(files);

    return locked;
}

/* Copyright 2007-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

