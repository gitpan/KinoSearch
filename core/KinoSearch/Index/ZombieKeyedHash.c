#define C_KINO_ZOMBIEKEYEDHASH
#include "KinoSearch/Util/ToolSet.h"

#include "KinoSearch/Index/ZombieKeyedHash.h"
#include "KinoSearch/Plan/FieldType.h"
#include "KinoSearch/Util/MemoryPool.h"

ZombieKeyedHash*
ZKHash_new(MemoryPool *memory_pool, uint8_t primitive_id)
{
    ZombieKeyedHash *self 
        = (ZombieKeyedHash*)VTable_Make_Obj(ZOMBIEKEYEDHASH);
    Hash_init((Hash*)self, 0);
    self->mem_pool = (MemoryPool*)INCREF(memory_pool);
    self->prim_id  = primitive_id;
    return self;
}

void
ZKHash_destroy(ZombieKeyedHash *self)
{
    DECREF(self->mem_pool);
    SUPER_DESTROY(self, ZOMBIEKEYEDHASH);
}

Obj*
ZKHash_make_key(ZombieKeyedHash *self, Obj *key, int32_t hash_sum)
{
    UNUSED_VAR(hash_sum);
    Obj *retval = NULL;
    switch(self->prim_id & FType_PRIMITIVE_ID_MASK) {
        case FType_TEXT: {
                CharBuf *source = (CharBuf*)key;
                size_t size = ZCB_size() + CB_Get_Size(source) + 1;
                void *allocation = MemPool_grab(self->mem_pool, size);
                retval = (Obj*)ZCB_newf(allocation, size, "%o", source);
            }
            break;
        case FType_INT32: {
                size_t size = VTable_Get_Obj_Alloc_Size(INTEGER32);
                Integer32 *copy 
                    = (Integer32*)MemPool_grab(self->mem_pool, size);
                VTable_Init_Obj(INTEGER32, copy);
                Int32_init(copy, 0);
                Int32_Mimic(copy, key);
                retval = (Obj*)copy;
            }
            break;
        case FType_INT64: { 
                size_t size = VTable_Get_Obj_Alloc_Size(INTEGER64);
                Integer64 *copy 
                    = (Integer64*)MemPool_Grab(self->mem_pool, size);
                VTable_Init_Obj(INTEGER64, copy);
                Int64_init(copy, 0);
                Int64_Mimic(copy, key);
                retval = (Obj*)copy;
            }
            break;
        case FType_FLOAT32: {
            size_t size = VTable_Get_Obj_Alloc_Size(FLOAT32);
                Float32 *copy = (Float32*)MemPool_Grab(self->mem_pool, size);
                VTable_Init_Obj(FLOAT32, copy);
                Float32_init(copy, 0);
                Float32_Mimic(copy, key);
                retval = (Obj*)copy;
            }
            break;
        case FType_FLOAT64: {
            size_t size = VTable_Get_Obj_Alloc_Size(FLOAT64);
                Float64 *copy = (Float64*)MemPool_Grab(self->mem_pool, size);
                VTable_Init_Obj(FLOAT64, copy);
                Float64_init(copy, 0);
                Float64_Mimic(copy, key);
                retval = (Obj*)copy;
            }
            break;
        default: 
            THROW(ERR, "Unrecognized primitive id: %i8", self->prim_id);
    }

    /* FIXME This is a hack.  It will leak memory if host objects get cached,
     * which in the present implementation will happen as soon as the refcount
     * reaches 4.  However, we must never call Destroy() for these objects,
     * because they will try to free() their initial allocation, which is
     * invalid because it's part of a MemoryPool arena. */
    INCREF(retval);

    return retval;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

