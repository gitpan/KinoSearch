package KinoSearch::Util::StringHelper;

1;

__END__

__H__

#ifndef H_KINO_STRING_HELPER
#define H_KINO_STRING_HELPER 1

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

I32 Kino_StrHelp_string_diff(char*, char*, STRLEN, STRLEN);

#endif /* include guard */

__C__

#include "KinoSearchUtilStringHelper.h"

I32
Kino_StrHelp_string_diff(char *str1, char *str2, STRLEN len1, STRLEN len2) {
    STRLEN i, len;

    len = len1 <= len2 ? len1 : len2;

    for (i = 0; i < len; i++) {
        if (*str1++ != *str2++) 
            break;
    }
    return i;
}

__POD__

=begin devdocs

=head1 NAME

KinoSearch::Util::StringHelper

=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS etc.

See L<KinoSearch|KinoSearch> version 0.07.

=end devdocs
=cut
