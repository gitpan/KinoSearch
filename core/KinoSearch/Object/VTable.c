#define C_KINO_VTABLE
#define C_KINO_OBJ
#define KINO_USE_SHORT_NAMES
#define CHY_USE_SHORT_NAMES

#include <string.h>
#include <ctype.h>

#include "KinoSearch/Object/VTable.h"
#include "KinoSearch/Object/CharBuf.h"
#include "KinoSearch/Object/Err.h"
#include "KinoSearch/Object/Hash.h"
#include "KinoSearch/Object/LockFreeRegistry.h"
#include "KinoSearch/Object/VArray.h"
#include "KinoSearch/Util/Atomic.h"
#include "KinoSearch/Util/Memory.h"

size_t kino_VTable_offset_of_parent = offsetof(kino_VTable, parent);

// Remove spaces and underscores, convert to lower case. 
static void
S_scrunch_charbuf(CharBuf *source, CharBuf *target);

LockFreeRegistry *VTable_registry = NULL;

void
VTable_destroy(VTable *self)
{
    THROW(ERR, "Insane attempt to destroy VTable for class '%o'", self->name);
}

VTable*
VTable_clone(VTable *self)
{
    VTable *evil_twin 
        = (VTable*)Memory_wrapped_calloc(self->vt_alloc_size, 1);

    memcpy(evil_twin, self, self->vt_alloc_size);
    evil_twin->name = CB_Clone(self->name);
    evil_twin->ref.count = 1; 

    return evil_twin;
}

Obj*
VTable_inc_refcount(VTable *self)
{
    return (Obj*)self;
}

uint32_t
VTable_dec_refcount(VTable *self)
{
    UNUSED_VAR(self);
    return 1;
}

uint32_t
VTable_get_refcount(VTable *self)
{
    UNUSED_VAR(self);
    /* VTable_Get_RefCount() lies to other KinoSearch code about the refcount
     * because we don't want to have to synchronize access to the cached host
     * object to which we have delegated responsibility for keeping refcounts.
     * It always returns 1 because 1 is a positive number, and thus other KinoSearch
     * code will be fooled into believing it never needs to take action such
     * as initiating a destructor.
     * 
     * It's possible that the host has in fact increased the refcount of the
     * cached host object if there are multiple refs to it on the other side
     * of the KinoSearch/host border, but returning 1 is good enough to fool KinoSearch
     * code.
     */
    return 1;
}

void
VTable_override(VTable *self, kino_method_t method, size_t offset) 
{
    union { char *char_ptr; kino_method_t *func_ptr; } pointer;
    pointer.char_ptr = ((char*)self) + offset;
    pointer.func_ptr[0] = method;
}

CharBuf*
VTable_get_name(VTable *self)   { return self->name; }
VTable*
VTable_get_parent(VTable *self) { return self->parent; }
size_t
VTable_get_obj_alloc_size(VTable *self) { return self->obj_alloc_size; }

void
VTable_init_registry()
{
    LockFreeRegistry *reg = LFReg_new(256);
    if (Atomic_cas_ptr((void*volatile*)&VTable_registry, NULL, reg)) {
        return;
    }
    else {
        DECREF(reg);
    }
}

VTable*
VTable_singleton(const CharBuf *subclass_name, VTable *parent)
{
    if (VTable_registry == NULL) { 
        VTable_init_registry(); 
    }

    VTable *singleton = (VTable*)LFReg_Fetch(VTable_registry, (Obj*)subclass_name);
    if (singleton == NULL) {
        VArray *novel_host_methods;
        uint32_t num_novel;

        if (parent == NULL) {
            CharBuf *parent_class = VTable_find_parent_class(subclass_name);
            if (parent_class == NULL) {
                THROW(ERR, "Class '%o' doesn't descend from %o", subclass_name,
                    OBJ->name);
            }
            else {
                parent = VTable_singleton(parent_class, NULL);
                DECREF(parent_class);
            }
        }

        // Copy source vtable. 
        singleton = VTable_Clone(parent);

        // Turn clone into child. 
        singleton->parent = parent; 
        DECREF(singleton->name);
        singleton->name = CB_Clone(subclass_name);
        
        // Allow host methods to override. 
        novel_host_methods = VTable_novel_host_methods(subclass_name);
        num_novel = VA_Get_Size(novel_host_methods);
        if (num_novel) {
            Hash *meths = Hash_new(num_novel);
            uint32_t i;
            CharBuf *scrunched = CB_new(0);
            ZombieCharBuf *callback_name = ZCB_BLANK();
            for (i = 0; i < num_novel; i++) {
                CharBuf *meth = (CharBuf*)VA_fetch(novel_host_methods, i);
                S_scrunch_charbuf(meth, scrunched);
                Hash_Store(meths, (Obj*)scrunched, INCREF(&EMPTY));
            }
            for (i = 0; singleton->callbacks[i] != NULL; i++) {
                kino_Callback *const callback = singleton->callbacks[i];
                ZCB_Assign_Str(callback_name, callback->name,
                    callback->name_len);
                S_scrunch_charbuf((CharBuf*)callback_name, scrunched);
                if (Hash_Fetch(meths, (Obj*)scrunched)) {
                    VTable_Override(singleton, callback->func, 
                        callback->offset);
                }
            }
            DECREF(scrunched);
            DECREF(meths);
        }
        DECREF(novel_host_methods);

        // Register the new class, both locally and with host. 
        if (VTable_add_to_registry(singleton)) {
            // Doing this after registering is racy, but hard to fix. :( 
            VTable_register_with_host(singleton, parent);
        }
        else {
            DECREF(singleton);
            singleton = (VTable*)LFReg_Fetch(VTable_registry, (Obj*)subclass_name);
            if (!singleton) {
                THROW(ERR, "Failed to either insert or fetch VTable for '%o'",
                    subclass_name);
            }
        }
    }
    
    return singleton;
}

Obj*
VTable_make_obj(VTable *self)
{
    Obj *obj = (Obj*)Memory_wrapped_calloc(self->obj_alloc_size, 1);
    obj->vtable = self;
    obj->ref.count = 1;
    return obj;
}

Obj*
VTable_init_obj(VTable *self, void *allocation)
{
    Obj *obj = (Obj*)allocation;
    obj->vtable = self;
    obj->ref.count = 1;
    return obj;
}

Obj*
VTable_load_obj(VTable *self, Obj *dump)
{
    Obj_load_t load = (Obj_load_t)METHOD(self, Obj, Load);
    if (load == Obj_load) {
        THROW(ERR, "Abstract method Load() not defined for %o", self->name);
    }
    return load(NULL, dump);
}

static void
S_scrunch_charbuf(CharBuf *source, CharBuf *target)
{
    ZombieCharBuf *iterator = ZCB_WRAP(source);
    CB_Set_Size(target, 0);
    while (ZCB_Get_Size(iterator)) {
        uint32_t code_point = ZCB_Nip_One(iterator);
        if (code_point > 127) {
            THROW(ERR, "Can't fold case for %o", source);
        }
        else if (code_point != '_') {
            CB_Cat_Char(target, tolower(code_point));
        }
    }
}

bool_t
VTable_add_to_registry(VTable *vtable)
{
    if (VTable_registry == NULL) {
        VTable_init_registry();
    }
    if (LFReg_Fetch(VTable_registry, (Obj*)vtable->name)) {
        return false;
    }
    else {
        CharBuf *klass = CB_Clone(vtable->name);
        bool_t retval 
            = LFReg_Register(VTable_registry, (Obj*)klass, (Obj*)vtable);
        DECREF(klass);
        return retval;
    }
}

VTable*
VTable_fetch_vtable(const CharBuf *class_name)
{
    VTable *vtable = NULL;
    if (VTable_registry != NULL) {
        vtable = (VTable*)LFReg_Fetch(VTable_registry, (Obj*)class_name);
    }
    return vtable;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

