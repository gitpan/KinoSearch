#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>
#include <ctype.h>

#define KINO_WANT_SHAREDLOCK_VTABLE
#include "KinoSearch/Store/SharedLock.r"

#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Util/YAML.h"

SharedLock*
ShLock_new(Folder *folder, const ByteBuf *lock_name, const ByteBuf *agent_id, 
         i32_t timeout)
{
    CREATE(self, SharedLock, SHAREDLOCK);

    /* init */
    self->filename = NULL;

    /* assign */
    self->folder       = REFCOUNT_INC(folder);
    self->timeout      = timeout;
    self->lock_name    = BB_CLONE(lock_name);
    self->agent_id     = BB_CLONE(agent_id);

    return self;
}

bool_t
ShLock_do_obtain(SharedLock *self)
{
    u32_t i = 0;

    /* null filename indicates whether this particular instance is locked */
    if (   self->filename != NULL 
        && Folder_File_Exists(self->folder, self->filename)
    ) {
        /* don't allow double obtain */
        return false;
    }

    do {
        REFCOUNT_DEC(self->filename);
        self->filename = BB_CLONE(self->lock_name);
        BB_GROW(self->filename, self->filename->len + 10);
        BB_Cat_Str(self->filename, "-", 1);
        BB_Cat_I64(self->filename, ++i);
        BB_Cat_Str(self->filename, ".lock", 5);
    } while ( Folder_File_Exists(self->folder, self->filename) );

    return Lock_do_obtain((Lock*)self); /* super obtain */
}

void
ShLock_release(SharedLock *self)
{
    if (self->filename == NULL)
        return;

    Lock_release((Lock*)self); /* super release */ 

    /* null out filename */
    REFCOUNT_DEC(self->filename);
    self->filename = NULL;
}

bool_t
ShLock_is_locked(SharedLock *self)
{
    VArray *files = Folder_List(self->folder);
    u32_t i;
    bool_t locked = false;
    
    for (i = 0; i < files->size; i++) {
        ByteBuf *filename = (ByteBuf*)VA_Fetch(files, i);

        /* translation: $locked = 1 if $filename =~ /$lock_name-\d+\.lock$/ */
        if (   BB_Starts_With(filename, self->lock_name)
            && BB_Ends_With_Str(filename, ".lock", 5)
            && (filename->len >= self->lock_name->len + 5 + 2 )
        ) {
            char *ptr = filename->ptr + self->lock_name->len;
            char *const end = BBEND(filename) - 5;
            if (*ptr == '-') {
                ptr++;
                while (ptr < end && isdigit(*ptr))
                    ptr++;
            }
            if (ptr == end)
                locked = true;
        }
    }
    REFCOUNT_DEC(files);

    return locked;
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

