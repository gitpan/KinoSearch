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
#define KINO_METHOD(method_name) \
    struct kino_SemiColonHolder /* no-op which legalizes stray ; */
#define KINO_FINAL_METHOD(method_name) \
    struct kino_SemiColonHolder /* no-op which legalizes stray ; */
#define KINO_END_CLASS

typedef struct kino_Obj kino_Obj;
typedef struct KINO_OBJ_VTABLE KINO_OBJ_VTABLE;

struct kino_ByteBuf;

KINO_CLASS("KinoSearch::Util::Obj", "Obj", "");

struct kino_Obj {
    KINO_OBJ_VTABLE *_;
    chy_u32_t refcount;
};

/* Constructor.
 */
kino_Obj*
kino_Obj_new();

/* Decrement an objects refcount, calling destroy if it hits 0.
 */
void
kino_Obj_dec_refcount(kino_Obj*);

/* Abstract method - return a clone of the object.
 */
kino_Obj*
kino_Obj_clone(kino_Obj *self);
KINO_METHOD("Kino_Obj_Clone");

/* Generic destructor.  Frees the struct itself but not any complex member
 * elements.
 */
void
kino_Obj_destroy(kino_Obj *self);
KINO_METHOD("Kino_Obj_Destroy");

/* Indicate whether two objects are the same.  By default, compares the memory
 * address.
 */
chy_bool_t
kino_Obj_equals(kino_Obj *self, kino_Obj *other);
KINO_METHOD("Kino_Obj_Equals");

/* Return a hash code for the object -- by default, the memory address.
 */
chy_i32_t
kino_Obj_hash_code(kino_Obj *self);
KINO_METHOD("Kino_Obj_Hash_Code");

/* Indicate whether the object's ancestry includes the supplied parent class
 * name.
 */
chy_bool_t
kino_Obj_is_a(kino_Obj *self, KINO_OBJ_VTABLE *target_vtable);
KINO_METHOD("Kino_Obj_Is_A");

/* Generic stringification: ClassName@hex_mem_address
 */
struct kino_ByteBuf*
kino_Obj_to_string(kino_Obj *self);
KINO_METHOD("Kino_Obj_To_String");

/* Abstract method.  Serialize the object, concatenating onto the end of
 * [target].
 */
void
kino_Obj_serialize(kino_Obj *self, struct kino_ByteBuf *target);
KINO_METHOD("Kino_Obj_Serialize");

KINO_END_CLASS

/* A virtual table for vtable objects.  See KinoSearch/Util/VirtualTable.
 */
extern struct KINO_VIRTUALTABLE_VTABLE KINO_VIRTUALTABLE;

/* Access an object's refcount.
 */
#define KINO_REFCOUNT(_self) (_self)->refcount

/* Increment an object's refcount.  Evaluates to the object, allowing an
 * assignment idiom:
 *
 *    self->foo = REFCOUNT_INC(foo);
 */
#define KINO_REFCOUNT_INC(_self) ((_self)->refcount++, (_self))

/* Decrement an object's refcount, calling destroy on it if the refcount drops
 * to 0.
 */
#define KINO_REFCOUNT_DEC(_self) \
    do { \
        if (_self != NULL && --(_self)->refcount == 0) \
            Kino_Obj_Destroy(_self); \
    } while (0)

/* Convenience macro for Obj_Is_A that adds a cast for the vtable.
 */
#define KINO_OBJ_IS_A(var, vtable) \
    (var)->_->is_a((kino_Obj*)(var), (KINO_OBJ_VTABLE*)&(vtable))

/* Sentinel value indicating invalid document number.
 * 
 * TODO: This belongs somewhere else.  
 */
#define KINO_DOC_NUM_SENTINEL CHY_U32_MAX

/* Function pointer typedefs for common signatures, used to clean up various 
 * function declarations, struct definitions, etc.
 * 
 * TODO: These also belong somewhere else.
 */

/* "qsort" function signature.
 */
typedef int
(*kino_Obj_compare_t)(const void *a, const void *b);

/* PriorityQueue function signature.
 */
typedef chy_bool_t 
(*kino_Obj_less_than_t)(const void *a, const void *b);

/* Dispose of a discarded element.
 */
typedef void
(*kino_Obj_free_elem_t)(void *elem);

#ifdef KINO_USE_SHORT_NAMES
  #define REFCOUNT(_self)                 KINO_REFCOUNT(_self)
  #define REFCOUNT_INC(_self)             KINO_REFCOUNT_INC(_self)
  #define REFCOUNT_DEC(_self)             KINO_REFCOUNT_DEC(_self)
  #define OBJ_IS_A(_self, vtable)         KINO_OBJ_IS_A(_self, vtable)
  #define DOC_NUM_SENTINEL                KINO_DOC_NUM_SENTINEL
  #define Obj_compare_t                   kino_Obj_compare_t
  #define Obj_less_than_t                 kino_Obj_less_than_t
  #define Obj_free_elem_t                 kino_Obj_free_elem_t
#endif

#endif /* H_KINO_OBJ */

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

