#define KINO_USE_SHORT_NAMES
#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>

#define KINO_WANT_LOCK_VTABLE
#include "KinoSearch/Store/Lock.r"

#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Util/CClass.r"
#include "KinoSearch/Util/YAML.h"

#ifdef HAS_POSIX
  #include <signal.h>
  #include <unistd.h>
#endif

Lock*
Lock_new(Folder *folder, const ByteBuf *lock_name, const ByteBuf *lock_id, 
         i32_t timeout)
{
    CREATE(self, Lock, LOCK);

    /* assign */
    REFCOUNT_INC(folder);
    self->folder       = folder;
    self->timeout      = timeout;
    self->lock_name    = BB_CLONE(lock_name);
    self->lock_id      = BB_CLONE(lock_id);

    return self;
}

void
Lock_destroy(Lock *self)
{
    REFCOUNT_DEC(self->folder);
    REFCOUNT_DEC(self->lock_id);
    REFCOUNT_DEC(self->lock_name);
    free(self);
}

bool_t
Lock_obtain(Lock *self)
{
    kino_i32_t sleep_count = self->timeout / LOCK_POLL_INTERVAL;
    bool_t locked = Lock_Do_Obtain(self);
    
    while (!locked) {
        if (sleep_count-- <= 0)
            CONFESS("Couldn't get lock using %s", self->lock_name->ptr);
        sleep(1);
        locked = Lock_Do_Obtain(self);
    }

    return locked;
}

bool_t
Lock_do_obtain(Lock *self)
{
    Folder    *folder    = self->folder;
    ByteBuf   *lock_name = self->lock_name;
    OutStream *lock_stream;
    ByteBuf   *yaml_buf;

#ifdef HAS_POSIX
    /* attempt to delete dead lock files */
    if (Folder_File_Exists(folder, lock_name)) {
        ByteBuf *file_contents = Folder_Slurp_File(folder, lock_name);
        Hash *hash = (Hash*)YAML_parse_yaml(file_contents);
        if ( hash != NULL && OBJ_IS_A(hash, HASH) ) {
            ByteBuf *pid_bb     = (ByteBuf*)Hash_Fetch(hash, "pid", 3);
            ByteBuf *lock_id_bb = (ByteBuf*)Hash_Fetch(hash, "lock_id", 7);
            if (lock_id_bb != NULL
                && BB_Equals(lock_id_bb, (Obj*)self->lock_id)
                && pid_bb != NULL
            ) {
                int pid = strtol(pid_bb->ptr, NULL, 10);
                if (kill(pid, 0) && errno == ESRCH)
                    Folder_Delete_File(folder, lock_name);
            }
        }
        REFCOUNT_DEC(hash);
        REFCOUNT_DEC(file_contents);
    }
#endif /* HAS_POSIX */
    
    if (Folder_File_Exists(folder, lock_name))
        return false;

    /* write the pid and the host id to the lock file, using YAML */
    lock_stream = Folder_Open_OutStream(folder, lock_name);
    yaml_buf = BB_new(self->lock_id->len + 200);
    yaml_buf->len = sprintf(yaml_buf->ptr, "lock_id: '%s'\npid: %d\n",
        self->lock_id->ptr, getpid());
    OutStream_Write_Bytes(lock_stream, yaml_buf->ptr, yaml_buf->len);
    OutStream_SClose(lock_stream);
    REFCOUNT_DEC(lock_stream);
    REFCOUNT_DEC(yaml_buf);

    return true;
}

void
Lock_release(Lock *self)
{
    Folder_Delete_File(self->folder, self->lock_name);
}

bool_t
Lock_is_locked(Lock *self)
{
    return Folder_File_Exists(self->folder, self->lock_name);
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

