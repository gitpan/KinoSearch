#ifndef H_KINO_OBJ
#define H_KINO_OBJ 1

#include <stddef.h>
#include "charmony.h"

/* See boilerplater.pl. 
 */
#define KINO_CLASS(classname, class_nick, base_class) \
    struct kino_SemiColonHolder /* no-op which legalizes stray ; */
#define KINO_FINAL_CLASS(classname, class_nick, base_class) \
    struct kino_SemiColonHolder /* no-op which legalizes stray ; */
#define KINO_FUNCTION(func_def) func_def
#define KINO_METHOD(method_name, func_def) func_def
#define KINO_FINAL_METHOD(method_name, func_def) func_def
#define KINO_END_CLASS

typedef struct kino_Obj kino_Obj;
typedef struct KINO_OBJ_VTABLE KINO_OBJ_VTABLE;

struct kino_ByteBuf;

KINO_CLASS("KinoSearch::Util::Obj", "Obj", "");

struct kino_Obj {
    KINO_OBJ_VTABLE *_;
    kino_u32_t refcount;
};


/* Constructor.
 */
KINO_FUNCTION(
kino_Obj*
kino_Obj_new());

/* Abstract method - return a clone of the object.
 */
KINO_METHOD("Kino_Obj_Clone",
kino_Obj*
kino_Obj_clone(kino_Obj *self));

/* Generic destructor.  Frees the struct itself but not any complex member
 * elements.
 */
KINO_METHOD("Kino_Obj_Destroy",
void
kino_Obj_destroy(kino_Obj *self));

/* Indicate whether two objects are the same.  By default, compares the memory
 * address.
 */
KINO_METHOD("Kino_Obj_Equals",
kino_bool_t
kino_Obj_equals(kino_Obj *self, kino_Obj *other));

/* Return a hash code for the object -- by default, the memory address.
 */
KINO_METHOD("Kino_Obj_Hash_Code",
kino_i32_t
kino_Obj_hash_code(kino_Obj *self));

/* Indicate whether the object's ancestry includes the supplied parent class
 * name.
 */
KINO_METHOD("Kino_Obj_Is_A",
kino_bool_t
kino_Obj_is_a(kino_Obj *self, KINO_OBJ_VTABLE *target_vtable));

/* Generic stringification: ClassName@hex_mem_address
 */
KINO_METHOD("Kino_Obj_To_String",
struct kino_ByteBuf*
kino_Obj_to_string(kino_Obj *self));

/* Abstract method.  Serialize the object, concatenating onto the end of
 * [target].
 */
KINO_METHOD("Kino_Obj_Serialize",
void
kino_Obj_serialize(kino_Obj *self, struct kino_ByteBuf *target));

KINO_END_CLASS

/* A virtual table for vtable objects.  See KinoSearch/Util/VirtualTable.
 */
extern struct KINO_VIRTUALTABLE_VTABLE KINO_VIRTUALTABLE;

/* Access an object's refcount.
 */
#define KINO_REFCOUNT(_self) (_self)->refcount

/* Increment an object's refcount.
 */
#define KINO_REFCOUNT_INC(_self) (_self)->refcount++;

/* Decrement an object's refcount, calling destroy on it if the refcount drops
 * to 0.
 */
#define KINO_REFCOUNT_DEC(_self) \
    do { \
        if (_self != NULL && --(_self)->refcount == 0) \
            Kino_Obj_Destroy(_self); \
    } while (0)

#define KINO_OBJ_IS_A(var, vtable) \
    var->_->is_a((kino_Obj*)var, (KINO_OBJ_VTABLE*)&vtable)

#ifdef KINO_USE_SHORT_NAMES
  #define REFCOUNT(_self)                 KINO_REFCOUNT(_self)
  #define REFCOUNT_INC(_self)             KINO_REFCOUNT_INC(_self)
  #define REFCOUNT_DEC(_self)             KINO_REFCOUNT_DEC(_self)
  #define OBJ_IS_A(_self, vtable)         KINO_OBJ_IS_A(_self, vtable)
#endif

#endif /* H_KINO_OBJ */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

