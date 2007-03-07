/* XSHelper.h -- functions used by XS bindings.
 * 
 * WARNING -- this file may be a copy.  The original lives in xshelper/.
 */

#ifndef H_KINO_XSHELPER
#define H_KINO_XSHELPER 1

#include "charmony.h"
#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/Obj.r"
#include "KinoSearch/Util/ByteBuf.r"
#include "KinoSearch/Util/VArray.r"
#include "KinoSearch/Util/Hash.r"
#include "KinoSearch/Util/ViewByteBuf.r"

/* This typedef is used by the typemap to convert an SV to a package name
 * using a particular behavior -- see derive_class(), below.
 */
typedef char classname_char;


/* These typedefs are used by the typemap to populate ByteBufs with string
 * content from an SV after first converting to UTF-8.
 */
typedef kino_ByteBuf kino_ByteBuf_utf8;
typedef kino_ViewByteBuf kino_ViewByteBuf_utf8;

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define NEED_newRV_noinc_GLOBAL
#include "ppport.h"

/* Strip the prefix from some common kino_ symbols where we know there's no
 * conflict with Perl.  It's a little inconsistent to do this rather than leave
 * all symbols at full size, but the succinctness is worth it.
 */
#define CONFESS KINO_CONFESS
#define REFCOUNT_INC KINO_REFCOUNT_INC
#define REFCOUNT_DEC KINO_REFCOUNT_DEC

/* Given a string literal, tack a string length on after it.  Only works at
 * compile-time, and only with literals.
 */
#define SNL(str) (str ""), (sizeof(str) - 1)

/* Many KinoSearch classes need to provide accessors so that struct members
 * may be accessed from Perl.  Rather than provide an XSUB for each accessor,
 * we use one multipath accessor function per class, with several aliases.
 * All set functions have odd-numbered aliases, and all get functions have
 * even-numbered aliases.  These two macros serve as bookends for the switch
 * function.
 */
#define START_SET_OR_GET_SWITCH \
    SV *retval = &PL_sv_undef; \
    /* if called as a setter, make sure the extra arg is there */ \
    if (ix % 2 == 1) { \
        if (items != 2) \
            CONFESS("usage: $object->set_xxxxxx($val)"); \
    } \
    else { \
        if (items != 1) \
            CONFESS("usage: $object->get_xxxxx()"); \
    } \
    switch (ix) {

#define END_SET_OR_GET_SWITCH \
    default: CONFESS("Internal error. ix: %d", ix); \
             break; /* probably unreachable */ \
    } \
    if (ix % 2 == 0) { \
        XPUSHs( sv_2mortal(retval) ); \
        XSRETURN(1); \
    } \
    else { \
        XSRETURN(0); \
    }

/* Create a mortalized hash, built using a defaults hash and @_.
 */
HV*
build_args_hash(SV** stack, kino_i32_t start, kino_i32_t num_stack_elems, 
                char* defaults_hash_name);

/* Given a key, extract a SV* from a hash.  Perform error checking that the
 * perlapi functions leave out.
 */
SV* 
extract_sv(HV* hash, char* key, kino_i32_t key_len);

/* Given a key, extract a SV* from a hash and return its UV value.  Perform
 * error checking that the perlapi functions leave out.
 */
UV
extract_uv(HV* hash, char* key, kino_i32_t key_len);

/* Given a key, extract a SV* from a hash and return its IV value.  Perform
 * error checking that the perlapi functions leave out.
 */
IV
extract_iv(HV* hash, char* key, kino_i32_t key_len);

/* Given a key, extract a SV* from a hash and return its NV value.  Perform
 * error checking that the perlapi functions leave out.
 */
NV
extract_nv(HV* hash, char* key, kino_i32_t key_len);

/* Given a key, extract a SV* from a hash, determine whether it is an object
 * which inherits from [class], and extract a void pointer which the caller
 * may cast to the appropriate struct type.
 */
void*
extract_obj(HV *hash, char *key, STRLEN key_len, char *class);

/* Like extract_obj(), but will return NULL without warning if the hash value
 * is undef.
 */
void*
maybe_extract_obj(HV *hash, char *key, STRLEN key_len, char *class);

/* Given an SV* that may be either an object or a class name, return the
 * class name.  Morally equivalent to ( ref($class) || $class ).
 */
char*
derive_class(SV* either_sv);

/* Extract a struct pointer from a Perl object, checking class.
 */
#define EXTRACT_STRUCT( perl_obj, dest, cname, class_name ) \
    do { \
        if (sv_derived_from( perl_obj, class_name )) { \
            const IV tmp = SvIV( (SV*)SvRV(perl_obj) ); \
            dest = INT2PTR(cname, tmp); \
        } \
        else { \
            dest = NULL; /* suppress unused var warning */ \
            CONFESS("not a %s", class_name); \
        } \
    } while (0)

#define MAYBE_EXTRACT_STRUCT( perl_obj, dest, cname, class_name ) \
    do { \
        if ((SvOK(perl_obj)) && sv_derived_from( perl_obj, class_name )) { \
            const IV tmp = SvIV( (SV*)SvRV(perl_obj) ); \
            dest = INT2PTR(cname, tmp); \
        } \
    } while (0)

/* Compare the IV values of two scalars.  Used by PriorityQueue XS binding.
 */
kino_bool_t
less_than_sviv(const void *a, const void *b);

/* Wrapper for sv_free which is guaranteed not to include thread context
 * argument.
 */
void
kino_sv_free(void *sv);

/* Allocate a new ByteBuf and copy the SV's string into it.
 */
kino_ByteBuf*
sv_to_new_bb(SV *sv);

/* Copy an SV's string ptr into a temporary ByteBuf.  The ByteBuf must be
 * treated as const, and must not be freed by KS.
 */
#define SV_TO_TEMP_BB(sv, bb) \
    do { \
        bb._   = &KINO_BYTEBUF; \
        bb.ptr = SvPV_nolen(sv); \
        bb.len = SvCUR(sv); \
        bb.cap = SvLEN(sv); \
    } while (0)

/* Convert a ByteBuf into a new string SV.
 */
SV*
bb_to_sv(kino_ByteBuf *bb);

/* Convert a kino_VArray* to a Perl arrayref.
 */
SV*
karray_to_parray(kino_VArray *varray);

/* Convert a kino_Hash* into a Perl hashref. 
 */
SV*
khash_to_phash(kino_Hash *hash);

/* Wrap any kino_Obj* or subclass in a Perl object.
 */
SV*
kobj_to_pobj(void *vobj);

/* Deep conversion of kino objects to Perl objects -- ByteBufs to SVs, 
 * VArrays to Perl array refs, Hashes to Perl hashrefs, and any other object
 * to a Perl object wrapping the KS Obj.
 */
SV*
nat_obj_to_pobj(kino_Obj *obj);

#endif /* H_KINO_XSHELPER */

/* Copyright 2005-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

