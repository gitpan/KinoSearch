#include "KinoSearch/Util/ToolSet.h"

#include <errno.h>
#include <stdio.h>

#include "KinoSearch/Store/Lock.h"
#include "KinoSearch/Store/Folder.h"
#include "KinoSearch/Store/OutStream.h"
#include "KinoSearch/Util/Json.h"
#include "KinoSearch/Util/Compat/Sleep.h"
#include "KinoSearch/Util/Compat/ProcessID.h"

Lock*
Lock_init(Lock *self, Folder *folder, const CharBuf *name, 
          const CharBuf *hostname, i32_t timeout, i32_t interval)
{
    /* Validate */
    if (interval <= 0) {
        DECREF(self);
        THROW(ERR, "Invalid value for 'interval': %i32", interval);
    }

    /* Assign. */
    self->folder       = (Folder*)INCREF(folder);
    self->timeout      = timeout;
    self->name         = CB_Clone(name);
    self->hostname     = CB_Clone(hostname);
    self->interval     = interval;

    /* Derive. */
    self->filename = CB_Clone(name);
    CB_Cat_Trusted_Str(self->filename, ".lock", 5);

    return self;
}

void
Lock_destroy(Lock *self)
{
    DECREF(self->folder);
    DECREF(self->hostname);
    DECREF(self->name);
    DECREF(self->filename);
    FREE_OBJ(self);
}

CharBuf*
Lock_get_filename(Lock *self) { return self->filename; }

bool_t
Lock_obtain(Lock *self)
{
    float sleep_count = self->interval == 0 
                      ? 0.0f
                      : (float)self->timeout / self->interval;
    bool_t locked = Lock_Request(self);
    
    while (!locked) {
        sleep_count -= self->interval;
        if (sleep_count < 0) { break; }
        Sleep_millisleep(self->interval);
        locked = Lock_Request(self);
    }

    return locked;
}

/***************************************************************************/

LockFileLock*
LFLock_new(Folder *folder, const CharBuf *name, const CharBuf *hostname, 
           i32_t timeout, i32_t interval)
{
    LockFileLock *self = (LockFileLock*)VTable_Make_Obj(LOCKFILELOCK);
    return LFLock_init(self, folder, name, hostname, timeout, interval);
}

LockFileLock*
LFLock_init(LockFileLock *self, Folder *folder, const CharBuf *name, 
            const CharBuf *hostname, i32_t timeout, i32_t interval)
{
    Lock_init((Lock*)self, folder, name, hostname, timeout, interval);
    return self;
}

bool_t
LFLock_shared(LockFileLock *self) { UNUSED_VAR(self); return false; }

bool_t
LFLock_request(LockFileLock *self)
{
    Hash      *file_data; 
    bool_t     wrote_json;
    bool_t     success = false;
    bool_t     deletion_failed = false;
    CharBuf   *temp_name;
    
    if (Folder_Exists(self->folder, self->filename)) { return false; }

    /* Write pid, lock name, and hostname to the lock file as JSON. */
    file_data = Hash_new(3);
    Hash_Store_Str(file_data, "pid", 3, 
        (Obj*)CB_newf("%i64", (i64_t)PID_getpid() ) );
    Hash_Store_Str(file_data, "hostname", 8, INCREF(self->hostname));
    Hash_Store_Str(file_data, "name", 4, INCREF(self->name));

    /* Write to a temporary file, then use the creation of a hard link to
     * ensure atomic but non-destructive creation of the lockfile with its
     * complete contents. */
    temp_name = CB_newf("%o.temp", self->filename);
    wrote_json = Json_spew_json((Obj*)file_data, self->folder, temp_name);
    if (wrote_json) {
        success = Folder_Hard_Link(self->folder, temp_name, self->filename);
        deletion_failed = !Folder_Delete(self->folder, temp_name);
    }
    DECREF(file_data);

    /* Verify that our temporary file got zapped. */
    if (wrote_json && deletion_failed) {
        CharBuf *mess = MAKE_MESS("Failed to delete %o", temp_name);
        DECREF(temp_name);
        Err_throw_mess(ERR, mess);
    }
    DECREF(temp_name);

    return success;
}

void
LFLock_release(LockFileLock *self)
{
    if (Folder_Exists(self->folder, self->filename)) {
        LFLock_Maybe_Delete_File(self, self->filename, true, false);
    }
}

bool_t
LFLock_is_locked(LockFileLock *self)
{
    return Folder_Exists(self->folder, self->filename);
}

void
LFLock_clear_stale(LockFileLock *self)
{
    LFLock_Maybe_Delete_File(self, self->filename, false, true);
}

bool_t
LFLock_maybe_delete_file(LockFileLock *self, const CharBuf *filename,
                         bool_t delete_mine, bool_t delete_other) 
{
    Folder *folder      = self->folder;
    bool_t  success     = false;

    /* Only delete locks that start with our lock name. */
    if ( !CB_Starts_With(filename, self->name) ) 
        return false;

    /* Attempt to delete dead lock file. */
    if (Folder_Exists(folder, filename)) {
        Hash *hash = (Hash*)Json_slurp_json(folder, filename);
        if ( hash != NULL && OBJ_IS_A(hash, HASH) ) {
            CharBuf *pid_buf = (CharBuf*)Hash_Fetch_Str(hash, "pid", 3);
            CharBuf *hostname 
                = (CharBuf*)Hash_Fetch_Str(hash, "hostname", 8);
            CharBuf *name 
                = (CharBuf*)Hash_Fetch_Str(hash, "name", 4);

            /* Match hostname and lock name. */
            if (   hostname != NULL  
                && CB_Equals(hostname, (Obj*)self->hostname)
                && name != NULL
                && CB_Equals(name, (Obj*)self->name)
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
                        Err_throw_mess(ERR, mess);
                    }
                }
            }
        }
        DECREF(hash);
    }

    return success;
}


/***************************************************************************/

LockErr*
LockErr_new(CharBuf *message)
{
    LockErr *self = (LockErr*)VTable_Make_Obj(LOCKERR);
    return LockErr_init(self, message);
}

LockErr*
LockErr_init(LockErr *self, CharBuf *message)
{
    Err_init((Err*)self, message);
    return self;
}

LockErr*
LockErr_make(LockErr *self)
{
    UNUSED_VAR(self);
    return LockErr_new(CB_new(0));
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

