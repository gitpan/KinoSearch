#include "XSBind.h"

#include "KinoSearch/Obj/VTable.h"

#include "KinoSearch/Obj.h"
#include "KinoSearch/Util/Host.h"
#include "KinoSearch/Obj/CharBuf.h"
#include "KinoSearch/Obj/Err.h"
#include "KinoSearch/Util/MemManager.h"

static SV*
do_callback_sv(kino_Obj *obj, char *method, chy_u32_t num_args, va_list args);

#define PUSH_ARG(_args, _num_params) \
    do { \
        chy_u32_t arg_type = va_arg(_args, chy_u32_t); \
        char *label = va_arg(_args, char*); \
        if (_num_params > 1) { \
            XPUSHs( sv_2mortal( newSVpvn(label, strlen(label)) ) ); \
        } \
        switch (arg_type) { \
        case KINO_HOST_ARGTYPE_I32: { \
                chy_i32_t anI32 = va_arg(_args, chy_i32_t); \
                XPUSHs( sv_2mortal( newSViv(anI32) ) ); \
            } \
            break; \
        case KINO_HOST_ARGTYPE_FLOAT: { \
                /* Floats are promoted to doubles by variadic calling. */ \
                double aDouble = va_arg(_args, double); \
                XPUSHs( sv_2mortal( newSVnv(aDouble) ) ); \
            } \
            break; \
        case KINO_HOST_ARGTYPE_STR: { \
                kino_CharBuf *string = va_arg(_args, kino_CharBuf*); \
                XPUSHs( sv_2mortal( XSBind_cb_to_sv(string) ) ); \
            } \
            break; \
        case KINO_HOST_ARGTYPE_OBJ: { \
                kino_Obj* anObj = va_arg(_args, kino_Obj*); \
                SV *arg_sv = anObj == NULL \
                    ? newSV(0) \
                    : kino_XSBind_kobj_to_pobj(anObj); \
                XPUSHs( sv_2mortal(arg_sv) ); \
            } \
            break; \
        default: \
            KINO_THROW(KINO_ERR, "Unrecognized arg type: %u32", arg_type); \
        } \
    } while (0)

void
kino_Host_callback(void *vobj, char *method, chy_u32_t num_args, ...) 
{
    kino_Obj *obj = (kino_Obj*)vobj;
    dSP;
    va_list args;
    int count;
    chy_u32_t i;
    SV *invoker;
    kino_VTable *vtable;
    
    if (KINO_OBJ_IS_A(obj, KINO_VTABLE)) {
        vtable  = (kino_VTable*)obj;
        invoker = XSBind_cb_to_sv(vtable->name);
    }
    else {
        vtable  = obj->vtable;
        invoker = (SV*)Kino_Obj_To_Host(obj);
    }

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal(invoker) );

    va_start(args, num_args);
    for (i = 0; i < num_args; i++) {
        PUSH_ARG(args, num_args);
    }
    va_end(args);

    PUTBACK;

    count = call_method(method, G_VOID|G_DISCARD);
    if (count != 0) {
        KINO_THROW(KINO_ERR, "callback '%s' in '%o' returned too many values: %i32", 
            method, Kino_VTable_Get_Name(vtable), (chy_i32_t)count);
    }

    PUTBACK;
    FREETMPS;
    LEAVE;
}

chy_i32_t
kino_Host_callback_i(void *vobj, char *method, chy_u32_t num_args, ...) 
{
    kino_Obj *obj = (kino_Obj*)vobj;
    va_list args;
    SV *return_sv;
    chy_i32_t retval;

    va_start(args, num_args);
    return_sv = do_callback_sv(obj, method, num_args, args);
    va_end(args);
    retval = (chy_i32_t)SvIV(return_sv);

    FREETMPS;
    LEAVE;

    return retval;
}

float
kino_Host_callback_f(void *vobj, char *method, chy_u32_t num_args, ...) 
{
    kino_Obj *obj = (kino_Obj*)vobj;
    va_list args;
    SV *return_sv;
    float retval;

    va_start(args, num_args);
    return_sv = do_callback_sv(obj, method, num_args, args);
    va_end(args);
    retval = (float)SvNV(return_sv);

    FREETMPS;
    LEAVE;

    return retval;
}

kino_Obj*
kino_Host_callback_obj(void *vobj, char *method, 
                         chy_u32_t num_args, ...) 
{
    kino_Obj *obj = (kino_Obj*)vobj;
    va_list args;
    SV *temp_retval;
    kino_Obj *retval = NULL;

    va_start(args, num_args);
    temp_retval = do_callback_sv(obj, method, num_args, args);
    va_end(args);

    retval = XSBind_perl_to_kino(temp_retval);

    FREETMPS;
    LEAVE;

    return retval;
}

kino_CharBuf*
kino_Host_callback_str(void *vobj, char *method, chy_u32_t num_args, ...)
{
    kino_Obj *obj = (kino_Obj*)vobj;
    va_list args;
    SV *temp_retval;
    kino_CharBuf *retval = NULL;

    va_start(args, num_args);
    temp_retval = do_callback_sv(obj, method, num_args, args);
    va_end(args);

    /* Make a stringified copy. */
    if (temp_retval && XSBind_sv_defined(temp_retval)) {
        STRLEN len;
        char *ptr = SvPVutf8(temp_retval, len);
        retval = kino_CB_new_from_trusted_utf8(ptr, len);
    }

    FREETMPS;
    LEAVE;

    return retval;
}

void*
kino_Host_callback_nat(void *vobj, char *method, chy_u32_t num_args, ...)
{
    kino_Obj *obj = (kino_Obj*)vobj;
    va_list args;
    SV *retval;

    va_start(args, num_args);
    retval = do_callback_sv(obj, method, num_args, args);
    va_end(args);
    SvREFCNT_inc(retval);

    FREETMPS;
    LEAVE;

    return retval;
}

static SV*
do_callback_sv(kino_Obj *obj, char *method, chy_u32_t num_args, va_list args) 
{
    dSP;
    int num_returned;
    SV *return_val;
    SV *invoker;
    chy_u32_t i;
    
    if (KINO_OBJ_IS_A(obj, KINO_VTABLE)) {
        kino_VTable *vtable = (kino_VTable*)obj;
        invoker = XSBind_cb_to_sv(vtable->name);
    }
    else {
        invoker = (SV*)Kino_Obj_To_Host(obj);
    }

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal(invoker) );

    for (i = 0; i < num_args; i++) {
        PUSH_ARG(args, num_args);
    }

    PUTBACK;

    num_returned = call_method(method, G_SCALAR);

    SPAGAIN;

    if (num_returned != 1) {
        KINO_THROW(KINO_ERR, "Bad number of return vals from %s: %i32", method,
            (chy_i32_t)num_returned);
    }

    return_val = POPs;

    PUTBACK;

    return return_val;
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

