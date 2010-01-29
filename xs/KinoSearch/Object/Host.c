#include "XSBind.h"

#include "KinoSearch/Object/VTable.h"

#include "KinoSearch/Object/Obj.h"
#include "KinoSearch/Object/Host.h"
#include "KinoSearch/Object/CharBuf.h"
#include "KinoSearch/Object/Err.h"
#include "KinoSearch/Util/Memory.h"

static SV*
S_do_callback_sv(void *vobj, char *method, chy_u32_t num_args, va_list args);

/* Convert all arguments to Perl and place them on the Perl stack. 
 */
static CHY_INLINE void
SI_push_args(void *vobj, va_list args, chy_u32_t num_args)
{
    kino_Obj *obj = (kino_Obj*)vobj;
    SV *invoker;
    chy_u32_t i;
    dSP;
    
    if (Kino_Obj_Is_A(obj, KINO_VTABLE)) {
        kino_VTable *vtable = (kino_VTable*)obj;
        /* TODO: Creating a new class name SV every time is wasteful. */
        invoker = XSBind_cb_to_sv(Kino_VTable_Get_Name(vtable));
    }
    else {
        invoker = (SV*)Kino_Obj_To_Host(obj);
    }

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal(invoker) );

    for (i = 0; i < num_args; i++) {
        chy_u32_t arg_type = va_arg(args, chy_u32_t);
        char *label = va_arg(args, char*);
        if (num_args > 1) {
            XPUSHs( sv_2mortal( newSVpvn(label, strlen(label)) ) );
        }
        switch (arg_type & KINO_HOST_ARGTYPE_MASK) {
        case KINO_HOST_ARGTYPE_I32: {
                chy_i32_t value = va_arg(args, chy_i32_t);
                XPUSHs( sv_2mortal( newSViv(value) ) );
            }
            break;
        case KINO_HOST_ARGTYPE_I64: {
                chy_i64_t value = va_arg(args, chy_i64_t);
                if (sizeof(IV) == 8) {
                    XPUSHs( sv_2mortal( newSViv((IV)value) ) );
                }
                else {
                    /* lossy */
                    XPUSHs( sv_2mortal( newSVnv((double)value) ) );
                }
            }
            break;
        case KINO_HOST_ARGTYPE_F32:
        case KINO_HOST_ARGTYPE_F64: {
                /* Floats are promoted to doubles by variadic calling. */
                double value = va_arg(args, double);
                XPUSHs( sv_2mortal( newSVnv(value) ) );
            }
            break;
        case KINO_HOST_ARGTYPE_STR: {
                kino_CharBuf *string = va_arg(args, kino_CharBuf*);
                XPUSHs( sv_2mortal( XSBind_cb_to_sv(string) ) );
            }
            break;
        case KINO_HOST_ARGTYPE_OBJ: {
                kino_Obj* anObj = va_arg(args, kino_Obj*);
                SV *arg_sv = anObj == NULL
                    ? newSV(0)
                    : XSBind_kino_to_perl(anObj);
                XPUSHs( sv_2mortal(arg_sv) );
            }
            break;
        default:
            KINO_THROW(KINO_ERR, "Unrecognized arg type: %u32", arg_type);
        }
    }

    PUTBACK;
}

void
kino_Host_callback(void *vobj, char *method, chy_u32_t num_args, ...) 
{
    va_list args;
    
    va_start(args, num_args);
    SI_push_args(vobj, args, num_args);
    va_end(args);
    
    {
        dSP;
        int count = call_method(method, G_VOID|G_DISCARD);
        if (count != 0) {
            KINO_THROW(KINO_ERR, "callback '%s' returned too many values: %i32", 
                method, (chy_i32_t)count);
        }
        PUTBACK;
        FREETMPS;
        LEAVE;
    }
}

chy_i64_t
kino_Host_callback_i64(void *vobj, char *method, chy_u32_t num_args, ...) 
{
    va_list args;
    SV *return_sv;
    chy_i64_t retval;

    va_start(args, num_args);
    return_sv = S_do_callback_sv(vobj, method, num_args, args);
    va_end(args);
    if (sizeof(IV) == 8) {
        retval = (chy_i64_t)SvIV(return_sv);
    }
    else {
        if (SvIOK(return_sv)) {
            /* It's already no more than 32 bits, so don't convert. */
            retval = SvIV(return_sv);
        }
        else {
            /* Maybe lossy. */
            double temp = SvNV(return_sv);
            retval = (chy_i64_t)temp;
        }
    }

    FREETMPS;
    LEAVE;

    return retval;
}

double
kino_Host_callback_f64(void *vobj, char *method, chy_u32_t num_args, ...) 
{
    va_list args;
    SV *return_sv;
    double retval;

    va_start(args, num_args);
    return_sv = S_do_callback_sv(vobj, method, num_args, args);
    va_end(args);
    retval = SvNV(return_sv);

    FREETMPS;
    LEAVE;

    return retval;
}

kino_Obj*
kino_Host_callback_obj(void *vobj, char *method, 
                         chy_u32_t num_args, ...) 
{
    va_list args;
    SV *temp_retval;
    kino_Obj *retval = NULL;

    va_start(args, num_args);
    temp_retval = S_do_callback_sv(vobj, method, num_args, args);
    va_end(args);

    retval = XSBind_perl_to_kino(temp_retval);

    FREETMPS;
    LEAVE;

    return retval;
}

kino_CharBuf*
kino_Host_callback_str(void *vobj, char *method, chy_u32_t num_args, ...)
{
    va_list args;
    SV *temp_retval;
    kino_CharBuf *retval = NULL;

    va_start(args, num_args);
    temp_retval = S_do_callback_sv(vobj, method, num_args, args);
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
kino_Host_callback_host(void *vobj, char *method, chy_u32_t num_args, ...)
{
    va_list args;
    SV *retval;

    va_start(args, num_args);
    retval = S_do_callback_sv(vobj, method, num_args, args);
    va_end(args);
    SvREFCNT_inc(retval);

    FREETMPS;
    LEAVE;

    return retval;
}

static SV*
S_do_callback_sv(void *vobj, char *method, chy_u32_t num_args, va_list args) 
{
    SV *return_val;
    SI_push_args(vobj, args, num_args);
    {
        int num_returned = call_method(method, G_SCALAR);
        dSP;
        if (num_returned != 1) {
            KINO_THROW(KINO_ERR, "Bad number of return vals from %s: %i32", method,
                (chy_i32_t)num_returned);
        }
        return_val = POPs;
        PUTBACK;
    }
    return return_val;
}

/* Copyright 2006-2010 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

