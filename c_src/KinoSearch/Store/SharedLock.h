/** 
 * @class KinoSearch::Store::SharedLock SharedLock.r
 * @brief Shared (read) lock.
 *
 * SharedLock differs from Lock in that each caller gets its own lockfile.
 * Lockfiles still have filenames which begin with the lock name and end with
 * ".lock", but each is also assigned a unique number which gets pasted
 * between: foo-44.lock instead of foo.lock.
 * 
 * A SharedLock is considered fully released when no lock files with a given 
 * lock name are left.
 */
 
#ifndef H_KINO_SHAREDLOCK
#define H_KINO_SHAREDLOCK 1

#include <stddef.h>
#include "KinoSearch/Store/Lock.r"

struct kino_Folder;
struct kino_ByteBuf;

typedef struct kino_SharedLock kino_SharedLock;
typedef struct KINO_SHAREDLOCK_VTABLE KINO_SHAREDLOCK_VTABLE;

KINO_CLASS("KinoSearch::Store::SharedLock", "ShLock", 
    "KinoSearch::Store::Lock");

struct kino_SharedLock {
    KINO_SHAREDLOCK_VTABLE *_; 
    KINO_LOCK_MEMBER_VARS;
};

/* Constructor. 
 * @param folder
 * @param lock_name 
 * @param agent_id 
 * @param timeout
 */
kino_SharedLock*
kino_ShLock_new(struct kino_Folder *folder, 
              const struct kino_ByteBuf *lock_name, 
              const struct kino_ByteBuf *agent_id, 
              chy_i32_t timeout);

chy_bool_t
kino_ShLock_do_obtain(kino_SharedLock *self);
KINO_METHOD("Kino_ShLock_Do_Obtain");

/* Release the lock.
 */
void
kino_ShLock_release(kino_SharedLock *self);
KINO_METHOD("Kino_ShLock_Release");

/* @returns true if the resource is locked, false otherwise
 */
chy_bool_t
kino_ShLock_is_locked(kino_SharedLock *self);
KINO_METHOD("Kino_ShLock_Is_Locked");

KINO_END_CLASS

#endif /* H_KINO_SHAREDLOCK */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

