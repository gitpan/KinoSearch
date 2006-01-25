package KinoSearch::Util::Carp;

1;

__END__

__H__

#ifndef H_KINOSEARCH_UTIL_CARP
#define H_KINOSEARCH_UTIL_CARP 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilMemManager.h"

void Kino_confess (char*, ...);

#endif /* include guard */

__C__

#include "KinoSearchUtilCarp.h"

void Kino_confess (char* pat, ...) {
    char *error_str;
    int message_len;
    va_list args_ptr;
    SV* error_sv;

    Kino_New(0, error_str, 256, char);

    va_start(args_ptr, pat);
    message_len = vsnprintf(error_str, 256, pat, args_ptr);
    va_end(args_ptr);

    error_sv = newSVpv(error_str, message_len);
    Kino_Safefree(error_str);
    
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



__END__

=begin devdocs

=head1 NAME

KinoSearch::Util::Carp - stack traces from C

=head1 DESCRIPTION

This module makes it possible to invoke Carp::confess() from C.  Modules that
use it will need to "use Carp;".

=head1 TODO

At present, this module won't compile on systems where vsnprintf isn't
available.  This needs to be addressed without creating the buffer overflow
security problem that vsnprintf is designed to avoid.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05.

=end devdocs
=cut
