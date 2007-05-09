use strict;
use warnings;

package KinoSearch::Util::StringHelper;
use base qw( Exporter );

our @EXPORT_OK = qw(
    utf8_flag_on
    utf8_flag_off
    to_base36
    from_base36
);

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Util::StringHelper

=for comment 

Turn an SV's UTF8 flag on.  Equivalent to Encode::_utf8_on, but we don't have
to load Encode.

=cut

void
utf8_flag_on(sv)
    SV *sv;
PPCODE:
    SvUTF8_on(sv);

=for comment

Turn an SV's UTF8 flag off.

=cut

void
utf8_flag_off(sv)
    SV *sv;
PPCODE:
    SvUTF8_off(sv);

SV*
to_base36(num)
    chy_u32_t num;
CODE:
{
    kino_ByteBuf *bb = kino_StrHelp_to_base36(num);
    RETVAL = bb_to_sv(bb);
    REFCOUNT_DEC(bb);
}
OUTPUT: RETVAL

IV
from_base36(str)
    char *str;
CODE:
    RETVAL = strtol(str, NULL, 36);
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::StringHelper - String related utilities.

=head1 DESCRIPTION

String related utilities, e.g. string comparison functions.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
