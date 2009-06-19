#include "xs/XSBind.h"

void
kino_Err_throw_mess(kino_CharBuf *message) 
{
    dSP;
    SV *error_sv = XSBind_cb_to_sv(message);

    KINO_DECREF(message);
    sv_catpvn(error_sv, "\n\t", 2);

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal(error_sv) );
    PUTBACK;
    call_pv("Carp::confess", G_DISCARD);
    FREETMPS;
    LEAVE;
}

void
kino_Err_warn_mess(kino_CharBuf *message) 
{
    SV *error_sv = XSBind_cb_to_sv(message);
    KINO_DECREF(message);
    warn(SvPV_nolen(error_sv));
    SvREFCNT_dec(error_sv);
}

/* Copyright 2006-2009 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

