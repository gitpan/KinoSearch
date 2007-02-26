#ifndef H_KINO_MEMMANAGER
#define H_KINO_MEMMANAGER 1

#include "charmony.h"
#include <stdlib.h>

#define KINO_MALLOCATE(n,t) \
    (t*)malloc(n*sizeof(t))
#define KINO_CALLOCATE(n,t) \
    (t*)calloc(n,sizeof(t))
#define KINO_REALLOCATE(v,n,t) \
    (t*)realloc(v, n*sizeof(t))

/* malloc() an object, assign its vtable and give it an initial refcount of 1.
 */
#define KINO_CREATE(var, type, vtable) \
    type *var     = KINO_MALLOCATE(1, type); \
    var->_        = &vtable; \
    var->refcount = 1;

/* Alternative to CREATE, which creates a subclass when [class_name] is
 * non-NULL.
 */
#define KINO_CREATE_SUBCLASS(var, class_name, type, vtable) \
    type *var = KINO_MALLOCATE(1, type); \
    if (   class_name == NULL \
        || (strcmp(class_name, vtable.class_name) == 0) \
    ) { \
        var->_ = &vtable; \
    } \
    else { \
        var->_ = (vtable##_VTABLE*)kino_DynVT_singleton(class_name, \
            (KINO_OBJ_VTABLE*)&vtable, sizeof(vtable)); \
    } \
    var->refcount = 1;

#ifdef KINO_USE_SHORT_NAMES
  #define MALLOCATE(n,t)                  KINO_MALLOCATE(n,t)
  #define CALLOCATE(n,t)                  KINO_CALLOCATE(n,t)
  #define REALLOCATE(v,n,t)               KINO_REALLOCATE(v,n,t)
  #define CREATE(v,t,vt)                  KINO_CREATE(v,t,vt)
  #define CREATE_SUBCLASS(v,c,t,vt)       KINO_CREATE_SUBCLASS(v,c,t,vt)
#endif

#endif /* H_KINO_MEMMANAGER */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

