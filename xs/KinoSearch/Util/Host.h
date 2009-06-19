/** Callbacks to the host environment.
 * 
 * All the callback functions are variadic, and all are designed to take a
 * series of arguments using the ARG_XXX macros.
 * 
 *   i32_t area = Host_callback_i(self, "calc_area", 2, 
 *        ARG_I32("length", len),  ARG_I32("width", width) );
 * 
 * The first argument is void* to avoid the need for tiresome casting to Obj*,
 * but must always be a KS object.
 * 
 * If the invoker is a VTable, it will be used to make a class
 * callback rather than an object callback.
 */
 
#ifndef H_KINO_HOST
#define H_KINO_HOST 1

#include "KinoSearch/Obj.h"


#define KINO_HOST_ARGTYPE_I32    (chy_i32_t)0x00000001
#define KINO_HOST_ARGTYPE_I64    (chy_i32_t)0x00000002
#define KINO_HOST_ARGTYPE_FLOAT  (chy_i32_t)0x00000004
#define KINO_HOST_ARGTYPE_DOUBLE (chy_i32_t)0x00000008
#define KINO_HOST_ARGTYPE_STR    (chy_i32_t)0x00000010
#define KINO_HOST_ARGTYPE_OBJ    (chy_i32_t)0x00000011

#define KINO_ARG_I32(_label, _aI32) \
    KINO_HOST_ARGTYPE_I32, (_label), (_aI32)
#define KINO_ARG_F(_label, _aFloat) \
    KINO_HOST_ARGTYPE_FLOAT, (_label), (_aFloat)
#define KINO_ARG_STR(_label, _aString) \
    KINO_HOST_ARGTYPE_STR, (_label), (_aString)
#define KINO_ARG_OBJ(_label, _anObj) \
    KINO_HOST_ARGTYPE_OBJ, (_label), (_anObj)

/* Invoke an object method in a void context.
 */
void
kino_Host_callback(void *self, char *method, 
                     chy_u32_t num_args, ...);

/* Invoke an object method, expecting an integer.
 */
chy_i32_t
kino_Host_callback_i(void *self, char *method, 
                       chy_u32_t num_args, ...);

/* Invoke an object method, expecting a float.
 */
float
kino_Host_callback_f(void *self, char *method, 
                       chy_u32_t num_args, ...);

/* Invoke an object method, expecting a Obj-derived object back, or possibly
 * NULL.  In order to ensure that the host environment doesn't reclaim the
 * return value, it's refcount is increased by one, which the caller will have
 * to deal with.
 */
kino_Obj*
kino_Host_callback_obj(void *self, char *method, 
                         chy_u32_t num_args, ...);

/* Invoke an object method, expecting a host string of some kind back, which
 * will be converted into a newly allocated CharBuf.  May return NULL.
 */
kino_CharBuf*
kino_Host_callback_str(void *self, char *method, 
                         chy_u32_t num_args, ...);

/* Invoke an object method, expecting a host data structure back.  It's up to
 * the caller to know how to process it.
 */
void*
kino_Host_callback_nat(void *self, char *method, 
                         chy_u32_t num_args, ...);

#ifdef KINO_USE_SHORT_NAMES
  #define ARG_I32                 KINO_ARG_I32
  #define ARG_F                   KINO_ARG_F
  #define ARG_STR                 KINO_ARG_STR
  #define ARG_OBJ                 KINO_ARG_OBJ
  #define Host_callback           kino_Host_callback
  #define Host_callback_i         kino_Host_callback_i
  #define Host_callback_f         kino_Host_callback_f
  #define Host_callback_obj       kino_Host_callback_obj
  #define Host_callback_str       kino_Host_callback_str
  #define Host_callback_nat       kino_Host_callback_nat
#endif

#endif /* H_KINO_HOST */

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

