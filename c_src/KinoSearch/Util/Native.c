#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#define KINO_WANT_NATIVE_VTABLE
#include "KinoSearch/Util/Native.r"

#include "KinoSearch/Util/Obj.r"
#include "KinoSearch/Util/ByteBuf.r"
#include "KinoSearch/Util/Carp.h"
#include "KinoSearch/Util/MemManager.h"

static SV*
do_callback_sv(kino_Native *self, char *method, va_list args);

kino_Native*
kino_Native_new(void *nat_obj)
{
    KINO_CREATE(self, kino_Native, KINO_NATIVE);
    self->obj = newSVsv((SV*)nat_obj);
    return self;
}

void
kino_Native_destroy(kino_Native *self)
{
    SvREFCNT_dec((SV*)self->obj);
    free(self);
}

void
kino_Native_callback(kino_Native *self, char *method, ...) 
{
    dSP;
    SV *object = newSVsv(self->obj);
    va_list args;
    kino_ByteBuf *bb;
    int count;

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal(object) );

    va_start(args, method);

    while ( (bb = va_arg(args, kino_ByteBuf*)) != NULL ) {
        SV *const aSV = newSVpvn( bb->ptr, bb->len );
        XPUSHs( sv_2mortal(aSV) );
    }

    va_end(args);

    PUTBACK;

    count = call_method(method, G_VOID);
    if (count != 0) {
        KINO_CONFESS("callback '%s' in '%s' returned too many values: %d", 
            method, HvNAME(SvSTASH(SvRV(object))), count );
    }

    PUTBACK;
    FREETMPS;
    LEAVE;
}

kino_ByteBuf*
kino_Native_callback_bb(kino_Native *self, char *method, ...) 
{
    va_list args;
    SV *return_sv;
    kino_ByteBuf *retval;
    char *ptr;
    STRLEN len;

    va_start(args, method);
    return_sv = do_callback_sv(self, method, args);
    va_end(args);

    ptr = SvPV(return_sv, len);
    retval = kino_BB_new_str(ptr, len);

    FREETMPS;
    LEAVE;

    return retval;
}

chy_i32_t
kino_Native_callback_i(kino_Native *self, char *method, ...) 
{
    va_list args;
    SV *return_sv;
    chy_i32_t retval;

    va_start(args, method);
    return_sv = do_callback_sv(self, method, args);
    va_end(args);
    retval = (chy_i32_t)SvIV(return_sv);

    FREETMPS;
    LEAVE;

    return retval;
}

float
kino_Native_callback_f(kino_Native *self, char *method, ...) 
{
    va_list args;
    SV *return_sv;
    float retval;

    va_start(args, method);
    return_sv = do_callback_sv(self, method, args);
    va_end(args);
    retval = (float)SvNV(return_sv);

    FREETMPS;
    LEAVE;

    return retval;
}

kino_Obj*
kino_Native_callback_obj(kino_Native *self, char *method, ...) 
{
    va_list args;
    SV *temp_retval;
    IV temp_iv;
    kino_Obj *retval;

    va_start(args, method);
    temp_retval = do_callback_sv(self, method, args);
    va_end(args);

    /* make a stringified copy */
    temp_iv = SvIV(SvRV(temp_retval));
    retval = INT2PTR(kino_Obj*, temp_iv);

    FREETMPS;
    LEAVE;

    return retval;
}


static SV*
do_callback_sv(kino_Native *self, char *method, va_list args) 
{
    SV *object = newSVsv(self->obj);
    SV* return_val;
    int num_returned;
    kino_ByteBuf *bb;

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal(object) );

    while ( (bb = va_arg(args, kino_ByteBuf*)) != NULL ) {
        SV *const aSV = newSVpvn( bb->ptr, bb->len );
        XPUSHs( sv_2mortal(aSV) );
    }

    PUTBACK;

    num_returned = call_method(method, G_SCALAR);

    SPAGAIN;

    if (num_returned != 1) {
        KINO_CONFESS("Bad number of return vals from %s: %d", method,
            num_returned);
    }

    return_val = POPs;

    PUTBACK;

    return return_val;
}

/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

