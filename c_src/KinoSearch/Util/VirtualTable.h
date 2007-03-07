#ifndef H_KINO_VIRTUALTABLE
#define H_KINO_VIRTUALTABLE 1

/* VirtualTables "inherit" from Obj -- their first two members are a reference
 * to a VTable, and a refcount.  Most VirtualTable inheritors -- e.g.
 * HASH_VTABLE -- do not get refcounted and are never destroyed.  However,
 * dynamic subclasses use DynVirtuaTables, and their constructors and
 * destructors do refcount those.
 *
 * This base VirtualTable class is intended for use as a parent for all fixed
 * vtables * resolved at compile time.  There is no constructor function, and
 * destruction is prevented via a destroy() method which throws an error.
 */

#include "KinoSearch/Util/Obj.r"

typedef struct kino_VirtualTable kino_VirtualTable;
typedef struct KINO_VIRTUALTABLE_VTABLE KINO_VIRTUALTABLE_VTABLE;

KINO_CLASS("KinoSearch::Util::VirtualTable", "VirtualTable", 
           "KinoSearch::Util::Obj");

struct kino_VirtualTable {
    KINO_OBJ_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    KINO_OBJ_VTABLE *parent;
    const char *class_name;
};

KINO_METHOD("Kino_VirtualTable_Destroy",
void
kino_VirtualTable_destroy(kino_VirtualTable *self));

KINO_END_CLASS

#endif /* H_KINO_VIRTUALTABLE */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

