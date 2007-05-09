#ifndef H_KINO_INVINDEX
#define H_KINO_INVINDEX 1

#include "KinoSearch/Util/Obj.r"

struct kino_Folder;
struct kino_Schema;

typedef struct kino_InvIndex kino_InvIndex;
typedef struct KINO_INVINDEX_VTABLE KINO_INVINDEX_VTABLE;

KINO_CLASS("KinoSearch::InvIndex", "InvIndex", "KinoSearch::Util::Obj");

struct kino_InvIndex {
    KINO_INVINDEX_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    struct kino_Schema       *schema;
    struct kino_Folder       *folder;
};

/* Constructor.
 */
kino_InvIndex*
kino_InvIndex_new(struct kino_Schema *schema, struct kino_Folder *folder);

void 
kino_InvIndex_destroy(kino_InvIndex *self);
KINO_METHOD("Kino_InvIndex_Destroy");

KINO_END_CLASS

#endif /* H_KINO_INVINDEX */

/* Copyright 2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

