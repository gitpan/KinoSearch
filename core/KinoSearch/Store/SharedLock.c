#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>
#include <ctype.h>

#include "KinoSearch/Store/SharedLock.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/OutStream.h"

SharedLock*
ShLock_new(Folder *folder, const CharBuf *name, const CharBuf *hostname, 
           i32_t timeout, i32_t interval)
{
    SharedLock *self = (SharedLock*)VTable_Make_Obj(SHAREDLOCK);
    return ShLock_init(self, folder, name, hostname, timeout, interval);
}

SharedLock*
ShLock_init(SharedLock *self, Folder *folder, const CharBuf *name, 
            const CharBuf *hostname, i32_t timeout, i32_t interval)
{
    Lock_init((Lock*)self, folder, name, hostname, timeout, interval);

    /* Override. */
    DECREF(self->filename);
    self->filename = (CharBuf*)INCREF(&EMPTY);

    return self;
}

bool_t
ShLock_shared(SharedLock *self) { UNUSED_VAR(self); return true; }

bool_t
ShLock_request(SharedLock *self)
{
    u32_t i = 0;
    ShLock_request_t super_request 
        = (ShLock_request_t)SUPER_METHOD(SHAREDLOCK, ShLock, Request);

    /* EMPTY filename indicates whether this particular instance is locked. */
    if (   self->filename != (CharBuf*)&EMPTY 
        && Folder_Exists(self->folder, self->filename)
    ) {
        /* Don't allow double obtain. */
        return false;
    }

    DECREF(self->filename);
    self->filename = CB_new(CB_Get_Size(self->name) + 10);
    do {
        CB_setf(self->filename, "%o-%u32.lock", self->name, ++i);
    } while ( Folder_Exists(self->folder, self->filename) );

    return super_request(self);
}

void
ShLock_release(SharedLock *self)
{
    if (self->filename != (CharBuf*)&EMPTY) {
        ShLock_release_t super_release
            = (ShLock_release_t)SUPER_METHOD(SHAREDLOCK, ShLock, Release);
        super_release(self);

        /* Empty out filename. */
        DECREF(self->filename);
        self->filename = (CharBuf*)INCREF(&EMPTY);
    }
}

void
ShLock_clear_stale(SharedLock *self)
{
    VArray *files = Folder_List(self->folder);
    u32_t i, max;
    
    /* Take a stab at any file that begins with our lock name. */
    for (i = 0, max = VA_Get_Size(files); i < max; i++) {
        CharBuf *filename = (CharBuf*)VA_Fetch(files, i);
        if (   CB_Starts_With(filename, self->name)
            && CB_Ends_With_Str(filename, ".lock", 5)
        ) {
            LFLock_Maybe_Delete_File(self, filename, false, true);
        }
    }

    DECREF(files);
}

bool_t
ShLock_is_locked(SharedLock *self)
{
    VArray *files = Folder_List(self->folder);
    u32_t i, max;
    bool_t locked = false;
    
    for (i = 0, max = VA_Get_Size(files); i < max; i++) {
        CharBuf *filename = (CharBuf*)VA_Fetch(files, i);

        /* Translation: 
         *   $locked = 1 if $filename =~ /^\Q$name-\d+\.lock$/ 
         */
        if (   CB_Starts_With(filename, self->name)
            && CB_Ends_With_Str(filename, ".lock", 5)
        ) {
            ZombieCharBuf temp = ZCB_make(filename);
            ZCB_Chop(&temp, sizeof(".lock") - 1);
            while(isdigit(ZCB_Code_Point_From(&temp, 1))) {
                ZCB_Chop(&temp, 1);
            }
            if (ZCB_Code_Point_From(&temp, 1) == '-') {
                ZCB_Chop(&temp, 1);
                if (CB_Equals(&temp, (Obj*)self->name)) {
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

