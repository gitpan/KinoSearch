#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>

#include "KinoSearch/Store/Lock.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/Json.h"
#include "KinoSearch/Util/Compat/Sleep.h"
#include "KinoSearch/Util/Compat/ProcessID.h"

static const ZombieCharBuf write_lock_name_cb  = ZCB_LITERAL("write");
static const ZombieCharBuf commit_lock_name_cb = ZCB_LITERAL("commit");
const ZombieCharBuf *Lock_write_lock_name  = &write_lock_name_cb;
const ZombieCharBuf *Lock_commit_lock_name = &commit_lock_name_cb;
u32_t Lock_read_lock_timeout   = 1000;
u32_t Lock_write_lock_timeout  = 1000;
u32_t Lock_commit_lock_timeout = 5000;

/* Delete a given lock file which meets these conditions:
 *    - lock name matches.
 *    - agent id matches.
 *
 * If delete_mine is false, don't delete a lock file which
 * matches this process's pid.  If delete_other is false, don't delete lock
 * files which don't match this process's pid.
 */
static bool_t
S_clear_file(Lock *self, const CharBuf *filename, bool_t delete_mine, 
             bool_t delete_other);

Lock*
Lock_new(Folder *folder, const CharBuf *lock_name, const CharBuf *agent_id, 
         i32_t timeout)
{
    Lock *self = (Lock*)VTable_Make_Obj(&LOCK);
    return Lock_init(self, folder, lock_name, agent_id, timeout);
}

Lock*
Lock_init(Lock *self, Folder *folder, const CharBuf *lock_name, 
          const CharBuf *agent_id, i32_t timeout)
{
    /* Assign. */
    self->folder       = (Folder*)INCREF(folder);
    self->timeout      = timeout;
    self->lock_name    = CB_Clone(lock_name);
    self->agent_id     = CB_Clone(agent_id);

    /* Derive. */
    self->filename = CB_Clone(lock_name);
    CB_Cat_Trusted_Str(self->filename, ".lock", 5);

    return self;
}

void
Lock_destroy(Lock *self)
{
    DECREF(self->folder);
    DECREF(self->agent_id);
    DECREF(self->lock_name);
    DECREF(self->filename);
    FREE_OBJ(self);
}

CharBuf*
Lock_get_filename(Lock *self) { return self->filename; }

bool_t
Lock_obtain(Lock *self)
{
    float sleep_count = (float)self->timeout / LOCK_POLL_INTERVAL;
    bool_t locked = Lock_Do_Obtain(self);
    
    while (!locked && sleep_count-- > 0) {
        Sleep_sleep(1);
        locked = Lock_Do_Obtain(self);
    }

    return locked;
}

bool_t
Lock_do_obtain(Lock *self)
{
    Hash      *file_data; 
    bool_t     success;
    
    if (Folder_Exists(self->folder, self->filename))
        return false;

    /* Write pid, lock name, and agent id to the lock file as YAML. */
    file_data = Hash_new(3);
    Hash_Store_Str(file_data, "pid", 3, 
        (Obj*)CB_newf("%i64", (i64_t)PID_getpid() ) );
    Hash_Store_Str(file_data, "agent_id", 8, INCREF(self->agent_id));
    Hash_Store_Str(file_data, "lock_name", 9, INCREF(self->lock_name));
    success = Json_spew_json((Obj*)file_data, self->folder, self->filename);

    /* Clean up. */
    DECREF(file_data);

    return success;
}

void
Lock_release(Lock *self)
{
    if (Folder_Exists(self->folder, self->filename)) {
        S_clear_file(self, self->filename, true, false);
    }
}

bool_t
Lock_is_locked(Lock *self)
{
    return Folder_Exists(self->folder, self->filename);
}

void
Lock_clear_stale(Lock *self)
{
    VArray *files = Folder_List(self->folder);
    u32_t i, max;
    
    /* Take a stab at any file that begins with our lock_name. */
    for (i = 0, max = VA_Get_Size(files); i < max; i++) {
        CharBuf *filename = (CharBuf*)VA_Fetch(files, i);
        if (   CB_Starts_With(filename, self->lock_name)
            && CB_Ends_With_Str(filename, ".lock", 5)
        ) {
            S_clear_file(self, filename, false, true);
        }
    }

    DECREF(files);
}

static bool_t
S_clear_file(Lock *self, const CharBuf *filename, bool_t delete_mine, 
             bool_t delete_other) 
{
    Folder *folder      = self->folder;
    bool_t  success     = false;

    /* Only delete locks that start with our lock_name. */
    if ( !CB_Starts_With(filename, self->lock_name) ) 
        return false;

    /* Attempt to delete dead lock file. */
    if (Folder_Exists(folder, filename)) {
        Hash *hash = (Hash*)Json_slurp_json(folder, filename);
        if ( hash != NULL && OBJ_IS_A(hash, HASH) ) {
            CharBuf *pid_buf   = (CharBuf*)Hash_Fetch_Str(hash, "pid", 3);
            CharBuf *agent_id  = (CharBuf*)Hash_Fetch_Str(hash, "agent_id", 8);
            CharBuf *lock_name = (CharBuf*)Hash_Fetch_Str(hash, "lock_name", 9);

            /* Match agent id and lock name. */
            if (   agent_id != NULL  
                && CB_Equals(agent_id, (Obj*)self->agent_id)
                && lock_name != NULL
                && CB_Equals(lock_name, (Obj*)self->lock_name)
                && pid_buf != NULL
            ) {
                /* Verify that pid is either mine or dead. */
                int pid = (int)CB_To_I64(pid_buf);
                         /* This process. */
                if (   ( delete_mine && pid == PID_getpid() ) 
                         /* Dead pid. */
                    || ( delete_other && !PID_active(pid) ) 
                ) {
                    if (Folder_Delete(folder, filename)) {
                        success = true;
                    }
                    else {
                        CharBuf *mess 
                            = MAKE_MESS("Can't delete '%o'", filename);
                        DECREF(hash);
                        Err_throw_mess(mess);
                    }
                }
            }
        }
        DECREF(hash);
    }

    return success;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

