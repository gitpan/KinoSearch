#define C_KINO_OBJ
#define C_KINO_VTABLE
#include "xs/XSBind.h"

#include "KinoSearch/Obj/VTable.h"
#include "KinoSearch/Util/Host.h"
#include "KinoSearch/Util/Debug.h"
#include "KinoSearch/Util/MemManager.h"

kino_Obj*
kino_VTable_foster_obj(kino_VTable *self, void *host_obj)
{
    kino_Obj *obj 
        = (kino_Obj*)kino_MemMan_wrapped_calloc(self->obj_alloc_size, 1);
    SV *inner_obj = SvRV((SV*)host_obj);
    obj->vtable = (kino_VTable*)KINO_INCREF(self);
    sv_setiv(inner_obj, PTR2IV(obj));
    obj->ref.host_obj = inner_obj;
    KINO_IFDEF_DEBUG( kino_Debug_num_allocated++ );
    return obj;
}

void
kino_VTable_register_with_host(kino_VTable *singleton, kino_VTable *parent)
{
    /* Register class with host. */
    kino_Host_callback(KINO_VTABLE, "_register", 2, 
        KINO_ARG_OBJ("singleton", singleton), KINO_ARG_OBJ("parent", parent));
}

kino_VArray*
kino_VTable_novel_host_methods(const kino_CharBuf *class_name)
{
    return (kino_VArray*)kino_Host_callback_obj(KINO_VTABLE, 
        "novel_host_methods", 1, KINO_ARG_STR("class_name", class_name));
}

kino_CharBuf*
kino_VTable_find_parent_class(const kino_CharBuf *class_name)
{
    return kino_Host_callback_str(KINO_VTABLE, "find_parent_class", 1, 
        KINO_ARG_STR("class_name", class_name));
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

