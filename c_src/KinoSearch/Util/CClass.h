#ifndef H_KINO_CCLASS
#define H_KINO_CCLASS 1

#include "KinoSearch/Util/Obj.r"

struct kino_ByteBuf;
struct kino_Obj;

typedef struct kino_CClass kino_CClass;
typedef struct KINO_CCLASS_VTABLE KINO_CCLASS_VTABLE;

KINO_CLASS("KinoSearch::Util::CClass", "CClass", "KinoSearch::Util::Obj");

struct kino_CClass {
    KINO_CCLASS_VTABLE *_;
    kino_u32_t refcount;
};

/* Constructor -- for testing only.
 */
KINO_FUNCTION(
kino_CClass*
kino_CClass_new());

/* Invoke an object method in a void context.
 */
KINO_FUNCTION(
void
kino_CClass_callback(struct kino_Obj *self, char *method, ...));

/* Invoke an object method, expecting a string back in the form of a newly 
 * allocated ByteBuf*.
 */
KINO_FUNCTION(
struct kino_ByteBuf*
kino_CClass_callback_bb(struct kino_Obj *self, char *method, ...));

/* Invoke an object method, expecting an integer.
 */
KINO_FUNCTION(
kino_i32_t
kino_CClass_callback_i(struct kino_Obj *self, char *method, ...));

/* Invoke an object method, expecting a float.
 */
KINO_FUNCTION(
float
kino_CClass_callback_f(struct kino_Obj *self, char *method, ...));

/* Invoke an object method, expecting a CClass-derived object back.
 */
KINO_FUNCTION(
struct kino_Obj*
kino_CClass_callback_obj(struct kino_Obj *self, char *method, ...));

/* Temporary wrappers for Perl's SvREFCNT_inc and SvREFCNT_dec, until all 
 * classes are C-based.
 */
KINO_FUNCTION(
void
kino_CClass_svrefcount_inc(void *perlobj));
KINO_FUNCTION(
void
kino_CClass_svrefcount_dec(void *perlobj));

KINO_END_CLASS

#endif /* H_KINO_CCLASS */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

