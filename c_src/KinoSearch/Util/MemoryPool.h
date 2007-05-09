#ifndef H_KINO_MEMORYPOOL
#define H_KINO_MEMORYPOOL 1

#include "KinoSearch/Util/Obj.r"

/* Grab memory from the system in 1 MB chunks.  Don't release it until object
 * destruction.  Parcel the memory out on request.  
 * 
 * The release mechanism is fast but extremely crude, limiting the use of this
 * class to specific applications.
 */

typedef struct kino_MemoryPool kino_MemoryPool;
typedef struct KINO_MEMORYPOOL_VTABLE KINO_MEMORYPOOL_VTABLE;

KINO_FINAL_CLASS("KinoSearch::Util::MemoryPool", "MemPool", 
    "KinoSearch::Util::Obj");

struct kino_MemoryPool {
    KINO_MEMORYPOOL_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    chy_u32_t                  arena_size;
    struct kino_VArray        *arenas;
    chy_i32_t                  tick;
    char                      *buf;
    char                      *last_buf;
    char                      *limit;
    size_t                     consumed; /**< bytes allocated (not cap) */
};

/* Constructor.  If arena_size is 0, it will be set to 1 MiB.
 */
kino_MemoryPool*
kino_MemPool_new(chy_u32_t arena_size);

/* Run some tests.  (This belongs in a test file, but we don't have those for
 * C as of the creation of this function.)
 */
chy_bool_t
kino_MemPool_run_tests();

/* Allocate memory from the pool.
 */
void*
kino_MemPool_grab(kino_MemoryPool *self, size_t amount);
KINO_METHOD("Kino_MemPool_Grab");

/* Resize the last allocation. (*Only* the last allocation).
 */
void
kino_MemPool_resize(kino_MemoryPool *self, void *ptr, size_t revised_amount);
KINO_METHOD("Kino_MemPool_Resize");

/* Tell the pool to consider all previous allocations released.
 */
void
kino_MemPool_release_all(kino_MemoryPool *self);
KINO_METHOD("Kino_MemPool_Release_All");

/* Take ownership of all the arenas in another MemoryPool.  Can only be called
 * when the original memory pool has no outstanding allocations, typically
 * just after a call to Release_All.  The purpose is to support bulk
 * reallocation.
 */
void
kino_MemPool_eat(kino_MemoryPool *self, kino_MemoryPool *other);
KINO_METHOD("Kino_MemPool_Eat");

void
kino_MemPool_destroy(kino_MemoryPool *self);
KINO_METHOD("Kino_MemPool_Destroy");

KINO_END_CLASS

#endif /* H_KINO_MEMORYPOOL */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

