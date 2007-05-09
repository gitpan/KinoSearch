#include "KinoSearch/Util/ToolSet.h"

#define KINO_WANT_MEMORYPOOL_VTABLE
#include "KinoSearch/Util/MemoryPool.r"

static void
init_arena(MemoryPool *self, size_t amount);

#define DEFAULT_BUF_SIZE 0x100000 /* 1 MiB */

/* Enlarge amount so pointers will always be aligned.
 */
#define INCREASE_TO_WORD_MULTIPLE(_amount) \
    do { \
        const size_t _remainder = _amount % sizeof(void*); \
        if (_remainder) { \
            _amount += sizeof(void*); \
            _amount -= _remainder; \
        } \
    } while (0)

MemoryPool*
MemPool_new(u32_t arena_size)
{
    CREATE(self, MemoryPool, MEMORYPOOL);

    self->arena_size = arena_size = 0 ? arena_size : DEFAULT_BUF_SIZE;
    self->arenas     = VA_new(16);
    self->tick       = -1;
    self->buf        = NULL;
    self->limit      = NULL;
    self->consumed   = 0;
    
    return self;
}

void
MemPool_destroy(MemoryPool *self)
{
    REFCOUNT_DEC(self->arenas);
    free(self);
}

static void
init_arena(MemoryPool *self, size_t amount)
{
    ByteBuf *bb;
    i32_t i;

    /* indicate which arena we're using at present */
    self->tick++;

    if (self->tick < (i32_t)self->arenas->size) {
        /* in recycle mode, use previously acquired memory */
        bb = (ByteBuf*)VA_Fetch(self->arenas, self->tick);
        if (amount >= bb->len) {
            BB_GROW(bb, amount);
            bb->len = amount;
        }
    }
    else {
        /* in add mode, get more mem from system */
        size_t buf_size = (amount + 1) > self->arena_size 
            ? (amount + 1)
            : self->arena_size;
        char *ptr       = MALLOCATE(buf_size, char);
        if (ptr == NULL)
            CONFESS("Failed to allocate memory");
        bb = BB_new_steal(ptr, buf_size - 1, buf_size);
        VA_Push(self->arenas, (Obj*)bb);
        REFCOUNT_DEC(bb);
    }

    /* recalculate consumption to take into account blocked off space */
    self->consumed = 0;
    for (i = 0; i < self->tick; i++) {
        ByteBuf *bb = (ByteBuf*)VA_Fetch(self->arenas, i);
        self->consumed += bb->len;
    }

    self->buf   = bb->ptr;
    self->limit = BBEND(bb);
}

void*
MemPool_grab(MemoryPool *self, size_t amount)
{
    INCREASE_TO_WORD_MULTIPLE(amount);
    self->last_buf = self->buf;

    /* verify that we have enough stocked up, otherwise get more */
    self->buf += amount;
    if (self->buf >= self->limit) {
        /* get enough mem from system or die trying */
        init_arena(self, amount);
        self->last_buf = self->buf;
        self->buf += amount;
    }

    /* track bytes we've allocated from this pool */
    self->consumed += amount;

    return self->last_buf;
}

void
MemPool_resize(MemoryPool *self, void *ptr, size_t new_amount)
{
    const size_t last_amount = self->buf - self->last_buf;
    INCREASE_TO_WORD_MULTIPLE(new_amount);

    if (ptr != self->last_buf) {
        CONFESS("Not the last pointer allocated.");
    }
    else {
        if (new_amount <= last_amount) {
            const size_t difference = last_amount - new_amount;
            self->buf      -= difference;
            self->consumed -= difference;
        }
        else {
            CONFESS("Can't resize to greater amount: %u > %u", 
                (unsigned)new_amount, (unsigned)last_amount);
        }
    }
}

void
MemPool_release_all(MemoryPool *self)
{
    self->tick     = -1;
    self->buf      = NULL;
    self->last_buf = NULL;
    self->limit    = NULL;
}

void
MemPool_eat(MemoryPool *self, MemoryPool *other) {
    i32_t i;
    if (self->buf != NULL)
        CONFESS("Memory pool is not empty");

    /* move active arenas from other to self */
    for (i = 0; i <= other->tick; i++) {
        ByteBuf *arena = (ByteBuf*)VA_Shift(other->arenas);
        /* maybe displace existing arena */
        VA_Store(self->arenas, i, (Obj*)arena); 
        REFCOUNT_DEC(arena);
    }
    self->tick     = other->tick;
    self->last_buf = other->last_buf;
    self->buf      = other->buf;
    self->limit    = other->limit;
}

bool_t
MemPool_run_tests()
{
    MemoryPool *mem_pool  = MemPool_new(0);
    MemoryPool *other     = MemPool_new(0);
    char *ptr_a, *ptr_b;

    ptr_a = MemPool_Grab(mem_pool, 10);
    strcpy(ptr_a, "foo");
    MemPool_Release_All(mem_pool);

    ptr_b = MemPool_Grab(mem_pool, 10);
    if ( strcmp(ptr_b, "foo") != 0 ) 
        CONFESS("Didn't recycle RAM on Release_All");

    ptr_a = mem_pool->buf;
    MemPool_Resize(mem_pool, ptr_b, 6);
    if (mem_pool->buf >= ptr_a)
        CONFESS("Resize didn't resize");

    ptr_a = MemPool_Grab(other, 20);
    MemPool_Release_All(other);
    MemPool_Eat(other, mem_pool);
    if (other->buf != mem_pool->buf || other->buf == NULL)
        CONFESS("Didn't eat");

    REFCOUNT_DEC(mem_pool);
    REFCOUNT_DEC(other);

    return  true;
}

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

