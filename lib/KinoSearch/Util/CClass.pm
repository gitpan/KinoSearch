package KinoSearch::Util::CClass;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base('KinoSearch::Util::Class');

1;

__END__

__H__

#ifndef H_KINO_CCLASS
#define H_KINO_CCLASS 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "KinoSearchUtilCarp.h"

#define KINO_START_SET_OR_GET_SWITCH                                \
    /* if called as a setter, make sure the extra arg is there */   \
    if (ix % 2 == 1 && items != 2)                                  \
        croak("usage: $seg_term_enum->set_xxxxxx($val)");           \
    switch (ix) {

#define KINO_END_SET_OR_GET_SWITCH                                  \
    default: Kino_confess("Internal error. ix: %d", ix);            \
             RETVAL = &PL_sv_undef; /* quiet compiler warning */    \
             break; /* probably unreachable */                      \
    }

#define Kino_extract_struct( perl_obj, dest, cname, class ) \
     if (sv_derived_from( perl_obj, class )) {              \
         IV tmp = SvIV( (SV*)SvRV(perl_obj) );              \
         dest = INT2PTR(cname, tmp);                        \
     }                                                      \
     else {                                                 \
         dest = NULL; /* suppress unused var warning */     \
         Kino_confess("not a %s", class);                   \
     }

#define Kino_extract_anon_struct( perl_obj, dest )                  \
     if (sv_derived_from( perl_obj, "KinoSearch::Util::CClass" )) { \
         IV tmp = SvIV( (SV*)SvRV(perl_obj) );                      \
         dest = INT2PTR(void*, tmp);                                \
     }                                                              \
     else {                                                         \
         dest = NULL; /* suppress unused var warning */             \
         Kino_confess("not derived from KinoSearch::Util::CClass"); \
     }

#define Kino_extract_struct_from_hv(hash, dest, key, key_len, cname, class) \
    {                                                                       \
        SV **sv_ptr;                                                        \
        sv_ptr = hv_fetch(hash, key, key_len, 0);                           \
        if (sv_ptr == NULL)                                                 \
            Kino_confess("Failed to retrieve hash entry '%s'", key);        \
        if (sv_derived_from( *sv_ptr, class )) {                            \
            IV tmp = SvIV( (SV*)SvRV(*sv_ptr) );                            \
            dest   = INT2PTR(cname, tmp);                                   \
        }                                                                   \
        else {                                                              \
            dest = NULL; /* suppress unused var warning */                  \
            Kino_confess("not a %s", class);                                \
        }                                                                   \
    }

#endif /* include guard */

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Util::CClass - base class for C-struct objects

=head1 DESCRIPTION

KinoSearch's C-struct objects use this as a base class, rather than
KinoSearch::Util::Class.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.163.

=end devdocs
=cut
