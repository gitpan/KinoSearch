#include "KinoSearch/Util/Carp.h"

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

static void
do_confess(SV *error_sv);

/* fallback in case variadic macros aren't available */
#ifndef KINO_HAS_VARIADIC_MACROS
void
KINO_CONFESS(char *pat, ...)
{
    va_list args;
    SV *const error_sv = newSV(0);

    va_start(args, pat);
    sv_vsetpvf(error_sv, pat, &args);
    va_end(args);

    do_confess(error_sv);
}
void
Kino_Carp_Warn(char *pat, ...)
{
    va_list args;
    SV *const error_sv = newSV(0);

    va_start(args, pat);
    sv_vsetpvf(error_sv, pat, &args);
    va_end(args);

    fprintf(stderr, "%s\n", SvPV_nolen(error_sv));
    SvREFCNT_dec(error_sv);
}
#endif


void
kino_Carp_warn_at(const char *file, int line, const char *func, 
                  const char *pat, ...)
{
    va_list args;
    SV *error_sv = newSVpvn("", 0);

    va_start(args, pat);
    sv_vcatpvf(error_sv, pat, &args);
    va_end(args);

    if (func != NULL)
        sv_catpvf(error_sv, " at %s:%d %s ", file, line, func);
    else 
        sv_catpvf(error_sv, " at %s:%d", file, line);

    fprintf(stderr, "%s\n", SvPV_nolen(error_sv));
    SvREFCNT_dec(error_sv);
}


void
kino_Carp_confess_at(const char *file, int line, const char *func, 
                     const char *pat, ...)
{
    va_list args;
    SV *error_sv;

    if (func != NULL)
        error_sv = newSVpvf("Error in function %s at %s:%d: ", func, file, 
            line);
    else 
        error_sv = newSVpvf("Error at %s:%d: ", file, line);

    va_start(args, pat);
    sv_vcatpvf(error_sv, pat, &args);
    va_end(args);

    sv_catpvn(error_sv, "\n\t", 2);

    do_confess(error_sv);
}


void
do_confess(SV *error_sv) 
{
    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs( sv_2mortal(error_sv) );
    PUTBACK;
    call_pv("Carp::confess", G_DISCARD);
    FREETMPS;
    LEAVE;
}



/* Copyright 2006-2007 Marvin Humphrey
 *
 * This program is free software; you can redistribute it and/or modify
 * under the same terms as Perl itself.
 */

