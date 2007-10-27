#define KINO_USE_SHORT_NAMES

#include <string.h>

#define KINO_WANT_DYNVIRTUALTABLE_VTABLE
#include "KinoSearch/Util/DynVirtualTable.r"

#include "KinoSearch/Util/ByteBuf.r"
#include "KinoSearch/Util/Hash.r"
#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/MemManager.h"

Hash *DynVT_registry = NULL;

/* Wrap an objects original destroy method.  Call destroy on the object, then
 * REFCOUNT_DEC the dynamic virtual table.
 */
static void
DynVT_obj_destroy_wrapper(Obj* obj);

/* Constructor.  Returns singletons, keyed by class name.
 */
kino_DynVirtualTable*
DynVT_singleton(const char *subclass_name, KINO_OBJ_VTABLE *parent, 
                size_t parent_size)
{
    DynVirtualTable *self;

    if (DynVT_registry == NULL)
        DynVT_registry = Hash_new(0);

    self = (DynVirtualTable*)Hash_Fetch(DynVT_registry, subclass_name,
        strlen(subclass_name));

    if (self != NULL) {
        REFCOUNT_INC(self);
    }
    else {
        /* copy source vtable */
        self = (DynVirtualTable*)malloc(parent_size);
        memcpy(self, parent, parent_size);

        /* override parts of the source vtable */
        REFCOUNT_INC(parent);
        self->_          = &DYNVIRTUALTABLE; 
        self->refcount   = 1; /* replacing whatever the orig recount was */
        self->parent     = parent;
        self->class_name = strdup(subclass_name);
        
        /* wrap the original vtable's destroy */
        ((KINO_OBJ_VTABLE*)self)->destroy = DynVT_obj_destroy_wrapper;

        /* store the virtual table in the registry */
        Hash_Store(DynVT_registry, subclass_name, strlen(subclass_name),
            (Obj*)self);
    }
    
    return self;
}

void
DynVT_destroy(DynVirtualTable *self)
{
    REFCOUNT_DEC(self->parent);

    /* ignore const */
    free((char*)self->class_name);

    free(self);
}

static void
DynVT_obj_destroy_wrapper(Obj* obj)
{
    DynVirtualTable *self = (DynVirtualTable*)obj->_;
    Obj_destroy_t original_destroy = self->parent->destroy;

    /* First, destroy the object (which depends on self to find its destroy
     * method. */
    original_destroy(obj);

    /* Now that the object is gone, think about destroying self.
     */
    REFCOUNT_DEC(self);
    if (self->refcount == 1) { 
        const size_t name_len = strlen(self->class_name);
        Hash_Delete(DynVT_registry, self->class_name, name_len);
    }

    /* and last, zap the registry when there are no more entries */
    if (DynVT_registry->size == 0) {
        REFCOUNT_DEC(DynVT_registry);
        DynVT_registry = NULL;
    }
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

