#ifndef H_KINO_DYNVIRTUALTABLE
#define H_KINO_DYNVIRTUALTABLE 1

#include "KinoSearch/Util/VirtualTable.r"

typedef struct kino_DynVirtualTable kino_DynVirtualTable;
typedef struct KINO_DYNVIRTUALTABLE_VTABLE KINO_DYNVIRTUALTABLE_VTABLE;

struct kino_ByteBuf;
struct kino_Hash;

extern struct kino_Hash *DynVT_registry;

KINO_CLASS("KinoSearch::Util::DynVirtualTable", "DynVT", 
    "KinoSearch::Util::VirtualTable");

struct kino_DynVirtualTable {
    KINO_DYNVIRTUALTABLE_VTABLE *_;
    KINO_VIRTUALTABLE_MEMBER_VARS;
    /* There cannot be more members without conflicting with the vtables that
     * "inherit" from VirtualTable: KINO_OBJ_VTABLE and all of its
     * descendents.
     */
};

/* Constructor.  Returns singletons, keyed by class name.
 */
KINO_FUNCTION(
kino_DynVirtualTable*
kino_DynVT_singleton(const char *subclass_name, 
                     KINO_OBJ_VTABLE *parent, 
                     size_t parent_size));

KINO_METHOD("Kino_DynVT_Destroy",
void
kino_DynVT_destroy(kino_DynVirtualTable *self));

KINO_END_CLASS

#ifdef KINO_USE_SHORT_NAMES
#endif

#endif /* H_KINO_DYNVIRTUALTABLE */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

