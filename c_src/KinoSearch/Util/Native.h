/** 
 * @class KinoSearch::Util::Native Native.r
 * @brief Wrapper for the host language's native objects.
 */
 
#ifndef H_KINO_NATIVE
#define H_KINO_NATIVE 1

#include "KinoSearch/Util/Obj.r"

struct kino_ByteBuf;
struct kino_Obj;

typedef struct kino_Native kino_Native;
typedef struct KINO_NATIVE_VTABLE KINO_NATIVE_VTABLE;

KINO_CLASS("KinoSearch::Util::Native", "Native", "KinoSearch::Util::Obj");

struct kino_Native {
    KINO_NATIVE_VTABLE *_;
    KINO_OBJ_MEMBER_VARS;
    void *obj;
};

/* Constructor -- for testing only.
 */
kino_Native*
kino_Native_new();

/* Invoke an object method in a void context.
 */
void
kino_Native_callback(struct kino_Native *self, char *method, ...);

/* Invoke an object method, expecting a string back in the form of a newly 
 * allocated ByteBuf*.
 */
struct kino_ByteBuf*
kino_Native_callback_bb(struct kino_Native *self, char *method, ...);

/* Invoke an object method, expecting an integer.
 */
chy_i32_t
kino_Native_callback_i(struct kino_Native *self, char *method, ...);

/* Invoke an object method, expecting a float.
 */
float
kino_Native_callback_f(struct kino_Native *self, char *method, ...);

/* Invoke an object method, expecting a Obj-derived object back.
 */
struct kino_Obj*
kino_Native_callback_obj(struct kino_Native *self, char *method, ...);

void
kino_Native_destroy(kino_Native *self);
KINO_METHOD("Kino_Native_Destroy");

KINO_END_CLASS

#endif /* H_KINO_NATIVE */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

