/** 
 * @class KinoSearch::Store::Lock Lock.r
 * @brief Interprocess mutex lock.
 *
 * The Lock class produces an interprocess mutex lock.  It does not rely on
 * flock, but creates a lock "file".  What exactly constitutes that "file"
 * depends on the Folder implementation.
 * 
 * Each lock must have a name which is unique per resource to be locked.  The
 * filename for the lockfile will be derived from it, e.g. "write" will
 * produce a file "write.lock".
 *
 * Each lock also has an "agent id", a string which should be unique per-host;
 * it is used to help clear away stale lockfiles.
 */
 
#ifndef H_KINO_LOCK
#define H_KINO_LOCK 1

#include <stddef.h>
#include "KinoSearch/Util/Obj.r"

struct kino_Folder;
struct kino_ByteBuf;

typedef struct kino_Lock kino_Lock;
typedef struct KINO_LOCK_VTABLE KINO_LOCK_VTABLE;

/** The frequency, in milliseconds, with which attempts to secure a lock will
 * be made.
 */
#define KINO_LOCK_POLL_INTERVAL 1000

KINO_CLASS("KinoSearch::Store::Lock", "Lock", "KinoSearch::Util::Obj");

struct kino_Lock {
    KINO_LOCK_VTABLE *_; 
    KINO_OBJ_MEMBER_VARS;
    struct kino_Folder   *folder;    /**< the Folder where the lock resides */
    struct kino_ByteBuf  *lock_name; /**< identifies the lock */
    struct kino_ByteBuf  *filename;  /**< name of actual lock file */
    struct kino_ByteBuf  *agent_id;  /**< identifies the host */
    chy_i32_t             timeout;   /**< ms to continue retrying */
};

/* Constructor. 
 * @param folder
 * @param lock_name 
 * @param agent_id 
 * @param timeout
 */
kino_Lock*
kino_Lock_new(struct kino_Folder *folder, 
              const struct kino_ByteBuf *lock_name, 
              const struct kino_ByteBuf *agent_id, 
              chy_i32_t timeout);

/* Attempt to aquire lock once per second until the timeout has been reached.
 */
chy_bool_t
kino_Lock_obtain(kino_Lock *self);
KINO_METHOD("Kino_Lock_Obtain");

/*  Do the actual work to aquire the lock and return a boolean reflecting
 *  success/failure.
 */
chy_bool_t
kino_Lock_do_obtain(kino_Lock *self);
KINO_METHOD("Kino_Lock_Do_Obtain");

/* Release the lock.
 */
void
kino_Lock_release(kino_Lock *self);
KINO_METHOD("Kino_Lock_Release");

/* @returns true if the resource is locked, false otherwise
 */
chy_bool_t
kino_Lock_is_locked(kino_Lock *self);
KINO_METHOD("Kino_Lock_Is_Locked");

/* Clear all lock files associated with this lock name and agent id whose pid
 * is not active.
 */
void
kino_Lock_clear_stale(kino_Lock *self);
KINO_METHOD("Kino_Lock_Clear_Stale");

void
kino_Lock_destroy(kino_Lock *self);
KINO_METHOD("Kino_Lock_Destroy");

KINO_END_CLASS

#ifdef KINO_USE_SHORT_NAMES
  #define LOCK_POLL_INTERVAL KINO_LOCK_POLL_INTERVAL
#endif

#endif /* H_KINO_LOCK */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

