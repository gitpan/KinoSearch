#ifndef H_KINO_LOCKFACTORY
#define H_KINO_LOCKFACTORY 1

#include "KinoSearch/Util/Obj.r"

struct kino_Folder;
struct kino_ByteBuf;
struct kino_Lock;
struct kino_SharedLock;

typedef struct kino_LockFactory kino_LockFactory;
typedef struct KINO_LOCKFACTORY_VTABLE KINO_LOCKFACTORY_VTABLE;

KINO_CLASS("KinoSearch::Store::LockFactory", "LockFact", 
    "KinoSearch::Util::Obj");

struct kino_LockFactory {
    KINO_LOCKFACTORY_VTABLE *_; 
    KINO_OBJ_MEMBER_VARS;
    struct kino_Folder  *folder;
    struct kino_ByteBuf *agent_id;
};

/* Constructor. 
 */
kino_LockFactory*
kino_LockFact_new(struct kino_Folder *folder, 
                  const struct kino_ByteBuf *agent_id);

struct kino_Lock*
kino_LockFact_make_lock(kino_LockFactory *self, 
                        const struct kino_ByteBuf *lock_name, 
                        chy_i32_t timeout);
KINO_METHOD("Kino_LockFact_Make_Lock");

struct kino_SharedLock*
kino_LockFact_make_shared_lock(kino_LockFactory *self, 
                               const struct kino_ByteBuf *lock_name, 
                               chy_i32_t timeout);
KINO_METHOD("Kino_LockFact_Make_Shared_Lock");

void
kino_LockFact_destroy(kino_LockFactory *self);
KINO_METHOD("Kino_LockFact_Destroy");

KINO_END_CLASS

#endif /* H_KINO_LOCKFACTORY */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

