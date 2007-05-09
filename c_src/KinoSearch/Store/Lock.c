#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>

#define KINO_WANT_LOCK_VTABLE
#include "KinoSearch/Store/Lock.r"

#include "KinoSearch/Store/Folder.r"
#include "KinoSearch/Store/OutStream.r"
#include "KinoSearch/Util/YAML.h"

#include <signal.h> /* requires POSIX.  TODO: write alternative for MSVC */
#include <unistd.h>

/* Delete a given lock file which meets these conditions:
 *    - lock name matches.
 *    - agent id matches.
 *
 * If delete_mine is false, don't delete a lock file which
 * matches this process's pid.  If delete_other is false, don't delete lock
 * files which don't match this process's pid.
 */
static bool_t
clear_file(Lock *self, const ByteBuf *filename, bool_t delete_mine, 
           bool_t delete_other);

Lock*
Lock_new(Folder *folder, const ByteBuf *lock_name, const ByteBuf *agent_id, 
         i32_t timeout)
{
    CREATE(self, Lock, LOCK);

    /* assign */
    REFCOUNT_INC(folder);
    self->folder       = folder;
    self->timeout      = timeout;
    self->lock_name    = BB_CLONE(lock_name);
    self->agent_id     = BB_CLONE(agent_id);

    /* derive */
    self->filename = BB_CLONE(lock_name);
    BB_Cat_Str(self->filename, ".lock", 5);

    return self;
}

void
Lock_destroy(Lock *self)
{
    REFCOUNT_DEC(self->folder);
    REFCOUNT_DEC(self->agent_id);
    REFCOUNT_DEC(self->lock_name);
    REFCOUNT_DEC(self->filename);
    free(self);
}

bool_t
Lock_obtain(Lock *self)
{
    float sleep_count = self->timeout / LOCK_POLL_INTERVAL;
    bool_t locked = Lock_Do_Obtain(self);
    
    while (!locked && sleep_count-- > 0) {
        sleep(1);
        locked = Lock_Do_Obtain(self);
    }

    return locked;
}

bool_t
Lock_do_obtain(Lock *self)
{
    OutStream *lock_stream = Folder_Safe_Open_OutStream(self->folder, 
        self->filename);
    Hash      *file_data; 
    ByteBuf   *yaml_buf;
    ByteBuf   *pid_buf;
    
    if (lock_stream == NULL)
        return false;

    /* write pid, lock name, and agent id to the lock file as YAML */
    pid_buf = BB_new_i64( getpid() );
    file_data = Hash_new(3);
    Hash_Store(file_data, "pid", 3, (Obj*)pid_buf);
    Hash_Store(file_data, "agent_id", 8, (Obj*)self->agent_id);
    Hash_Store(file_data, "lock_name", 9, (Obj*)self->lock_name);
    yaml_buf = YAML_encode_yaml((Obj*)file_data);
    OutStream_Write_Bytes(lock_stream, yaml_buf->ptr, yaml_buf->len);

    /* clean up */
    OutStream_SClose(lock_stream);
    REFCOUNT_DEC(lock_stream);
    REFCOUNT_DEC(pid_buf);
    REFCOUNT_DEC(file_data);
    REFCOUNT_DEC(yaml_buf);

    return true;
}

void
Lock_release(Lock *self)
{
    clear_file(self, self->filename, true, false);
}

bool_t
Lock_is_locked(Lock *self)
{
    return Folder_File_Exists(self->folder, self->filename);
}

void
Lock_clear_stale(Lock *self)
{
    VArray *files = Folder_List(self->folder);
    u32_t i;
    
    /* take a stab at any file that begins with our lock_name */
    for (i = 0; i < files->size; i++) {
        ByteBuf *filename = (ByteBuf*)VA_Fetch(files, i);
        if (BB_Starts_With(filename, self->lock_name)) {
            clear_file(self, filename, false, true);
        }
    }

    REFCOUNT_DEC(files);
}

static bool_t
clear_file(Lock *self, const ByteBuf *filename, bool_t delete_mine, 
           bool_t delete_other) 
{
    Folder *folder      = self->folder;
    bool_t  success     = false;

    /* only delete locks that start with our lock_name */
    if ( !BB_Starts_With(filename, self->lock_name) ) 
        return false;

    /* attempt to delete dead lock file */
    if (Folder_File_Exists(folder, filename)) {
        ByteBuf *file_contents = Folder_Slurp_File(folder, filename);
        Hash *hash = (Hash*)YAML_parse_yaml(file_contents);
        if ( hash != NULL && OBJ_IS_A(hash, HASH) ) {
            ByteBuf *pid_bb    = (ByteBuf*)Hash_Fetch(hash, "pid", 3);
            ByteBuf *agent_id  = (ByteBuf*)Hash_Fetch(hash, "agent_id", 8);
            ByteBuf *lock_name = (ByteBuf*)Hash_Fetch(hash, "lock_name", 9);

            /* match agent id and lock name */
            if (   agent_id != NULL  
                && BB_Equals(agent_id, (Obj*)self->agent_id)
                && lock_name != NULL
                && BB_Equals(lock_name, (Obj*)self->lock_name)
                && pid_bb != NULL
            ) {
                /* verify that pid is either mine or dead */
                int pid = BB_To_I64(pid_bb);
                         /* this process */
                if (   ( delete_mine && pid == getpid() ) 
                         /* dead pid */
                    || ( delete_other && kill(pid, 0) && errno == ESRCH ) 
                ) {
                    Folder_Delete_File(folder, filename);
                    success = true;
                }
            }
        }
        REFCOUNT_DEC(hash);
        REFCOUNT_DEC(file_contents);
    }

    return success;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

