#ifndef H_KINO_LOCK
#define H_KINO_LOCK 1

#include <stddef.h>
#include "KinoSearch/Util/Obj.r"

struct kino_Folder;
struct kino_ByteBuf;

typedef struct kino_Lock kino_Lock;
typedef struct KINO_LOCK_VTABLE KINO_LOCK_VTABLE;

/* The frequency, in milliseconds, with which attempts to secure a lock will
 * be made.
 */
#define KINO_LOCK_POLL_INTERVAL 1000

KINO_CLASS("KinoSearch::Store::Lock", "Lock", "KinoSearch::Util::Obj");

struct kino_Lock {
    KINO_LOCK_VTABLE *_; 
    kino_u32_t refcount;
    struct kino_Folder      *folder;
    struct kino_ByteBuf     *lock_name;
    struct kino_ByteBuf     *lock_id;
    kino_i32_t               timeout;
};

/* Constructor. It's assumed that the necessary native methods will be defined
 * in the subclass.
 */
KINO_FUNCTION(
kino_Lock*
kino_Lock_new(struct kino_Folder *folder, 
              const struct kino_ByteBuf *lock_name, 
              const struct kino_ByteBuf *lock_id, 
              kino_i32_t timeout));

/* Attempt to aquire lock once per second until the timeout has been reached.
 */
KINO_METHOD("Kino_Lock_Obtain",
kino_bool_t
kino_Lock_obtain(kino_Lock *self));

/* Abstract method.  Do the actual work to aquire the lock and return a
 * boolean reflecting success/failure.
 */
KINO_METHOD("Kino_Lock_Do_Obtain",
kino_bool_t
kino_Lock_do_obtain(kino_Lock *self));

/* Abstract method.  Release the lock.
 */
KINO_METHOD("Kino_Lock_Release",
void
kino_Lock_release(kino_Lock *self));

/* Abstract method. Return true if the resource is locked, false otherwise.
 */
KINO_METHOD("Kino_Lock_Is_Locked",
kino_bool_t
kino_Lock_is_locked(kino_Lock *self));

KINO_METHOD("Kino_Lock_Destroy",
void
kino_Lock_destroy(kino_Lock *self));

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

