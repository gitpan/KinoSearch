/* XSBind.h -- Functions to help bind KinoSearch to Perl XS api.
 */

#ifndef H_KINO_XSBIND
#define H_KINO_XSBIND 1

#include "charmony.h"
#include "KinoSearch/Obj.h"
#include "KinoSearch/Obj/ByteBuf.h"
#include "KinoSearch/Obj/CharBuf.h"
#include "KinoSearch/Obj/Err.h"
#include "KinoSearch/Obj/Hash.h"
#include "KinoSearch/Obj/Num.h"
#include "KinoSearch/Obj/VArray.h"
#include "KinoSearch/Obj/VTable.h"

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define NEED_newRV_noinc_GLOBAL
#include "ppport.h"

/* Strip the prefix from some common kino_ symbols where we know there's no
 * conflict with Perl.  It's a little inconsistent to do this rather than
 * leave all symbols at full size, but the succinctness is worth it.
 */
#define THROW            KINO_THROW
#define WARN             KINO_WARN
#define OVERRIDDEN       KINO_OVERRIDDEN

/* Given either a class name or a perl object, manufacture a new KS
 * object suitable for supplying to a kino_Foo_init() function.
 */
kino_Obj*
kino_XSBind_new_blank_obj(SV *either_sv);

/* Test whether an SV is defined.  Handles "get" magic, unlike SvOK.
 */
chy_bool_t
kino_XSBind_sv_defined(SV *sv);

/* If the SV contains a KS object which passes an "isa" test against the
 * passed-in VTable, return a pointer to it.  If the vtable indicates that a
 * VArray or a Hash is desired and the SV contains the corresponding Perl data
 * structure, attempt to convert it to a mortalized KS copy.  If the desired
 * object cannot be derived, throw an exception.
 */
kino_Obj*
kino_XSBind_sv_to_kobj(SV *sv, kino_VTable *vtable);

/* If the SV contains a KS object which passes an "isa" test against the
 * passed-in VTable, return a pointer to it.  If not, but a ZombieCharBuf
 * would satisfy the "isa" test, stringify the SV, assign its string to
 * <code>zcb</code> and return a pointer to that instead.
 */
kino_Obj*
kino_XSBind_sv_to_kobj_or_zcb(SV *sv, kino_VTable *vtable, 
                              kino_ZombieCharBuf *zcb);

/* As XSBind_sv_to_kobj above, but returns NULL instead of throwing an
 * exception.
 */
kino_Obj*
kino_XSBind_maybe_sv_to_kobj(SV *sv, kino_VTable *vtable);

/* Given an SV* that may be either an object or a class name, return the
 * class name as a ZombieCharBuf.  Morally equivalent to 
 * ( ref($class) || $class ).
 */
kino_ZombieCharBuf
kino_XSBind_sv_to_class_name(SV* either_sv);

/* Convert a ByteBuf into a new string SV.
 */
SV*
kino_XSBind_bb_to_sv(const kino_ByteBuf *bb);

/* Convert a CharBuf into a new UTF-8 string SV.
 */
SV*
kino_XSBind_cb_to_sv(const kino_CharBuf *cb);

/* Deep conversion of KS objects to Perl objects -- CharBufs to UTF-8 SVs,
 * ByteBufs to SVs, VArrays to Perl array refs, Hashes to Perl hashrefs, and
 * any other object to a Perl object wrapping the KS Obj.
 */
SV*
kino_XSBind_kobj_to_pobj(kino_Obj *obj);

/* Turn on overloading for the supplied Perl object and its class.
 */
void
kino_XSBind_enable_overload(void *pobj);

/* Deep conversion of Perl data structures to KS objects -- Perl hash to
 * Hash*, Perl array to VArray*, and everything else stringified and turned to
 * a CharBuf.
 */
kino_Obj*
kino_XSBind_perl_to_kino(SV *sv);

void
kino_XSBind_allot_params(SV** stack, chy_i32_t start, 
                         chy_i32_t num_stack_elems, 
                         char* defaults_hash_name, ...);

/* Check the vtable function pointer for a method and determine whether it
 * differs from the original.  If it doesn't throw an exception.
 */
#define ABSTRACT_METHOD_CHECK(_self, _class_nick, _meth_name, _micro_name) \
    do { \
        kino_VTable *_my_vtable = *(kino_VTable**)_self; \
        if (KINO_METHOD(_my_vtable, _class_nick, _meth_name) \
             == (boil_method_t)kino_ ## _class_nick ## _ ## _micro_name \
        ) { \
            kino_CharBuf *_class_name = Kino_VTable_Get_Name(_my_vtable); \
            KINO_THROW(KINO_ERR, "Abstract method '%s' not defined by %o", \
                # _micro_name, _class_name \
            ); \
        } \
    } while (0)

/* Derive an SV from a KinoSearch object.  If the KS object is NULL, the SV
 * will be undef.
 *
 * The new SV has single refcount for which the caller must take
 * responsibility.
 */
#define KOBJ_TO_SV(_kobj_expression, _sv) \
    do { \
        kino_Obj *const _kobj = (kino_Obj*)(_kobj_expression); \
        if (_kobj == NULL) { \
            _sv = newSV(0); \
        } \
        else { \
            _sv = Kino_Obj_To_Host(_kobj); \
        } \
    } while (0)

/* As KOBJ_TO_SV above, except decrements the object's refcount after creating
 * the SV. This is useful when the KS expression creates a new refcount, e.g.
 * a call to a constructor.
 */
#define KOBJ_TO_SV_NOINC(_kobj_expression, _sv) \
    do { \
        kino_Obj *const _kobj = (kino_Obj*)(_kobj_expression); \
        if (_kobj == NULL) { \
            _sv = newSV(0); \
        } \
        else { \
            _sv = Kino_Obj_To_Host(_kobj); \
            Kino_Obj_Dec_RefCount(_kobj); \
        } \
    } while (0)

/* Given a string literal, tack a string length on after it.  (Only works at
 * compile-time, and only with literals.)
 */
#define SNL(str) (str ""), (sizeof(str) - 1)

/* Define short names for all the functions in this file.  Note that these
 * short names are ALWAYS in effect, since they are only used for Perl and we
 * can be confident they don't conflict with anything.  (It's prudent to use
 * full symbols nevertheless in case someone else defines e.g. a function
 * named "XSBind_sv_defined".)
 */
#define XSBind_new_blank_obj        kino_XSBind_new_blank_obj
#define XSBind_sv_defined           kino_XSBind_sv_defined
#define XSBind_sv_to_kobj           kino_XSBind_sv_to_kobj
#define XSBind_sv_to_kobj_or_zcb    kino_XSBind_sv_to_kobj_or_zcb
#define XSBind_maybe_sv_to_kobj     kino_XSBind_maybe_sv_to_kobj
#define XSBind_sv_to_class_name     kino_XSBind_sv_to_class_name
#define XSBind_bb_to_sv             kino_XSBind_bb_to_sv
#define XSBind_cb_to_sv             kino_XSBind_cb_to_sv
#define XSBind_kobj_to_pobj         kino_XSBind_kobj_to_pobj
#define XSBind_enable_overload      kino_XSBind_enable_overload
#define XSBind_perl_to_kino         kino_XSBind_perl_to_kino
#define XSBind_allot_params         kino_XSBind_allot_params

#endif /* H_KINO_XSBIND */

/* Copyright 2005-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

