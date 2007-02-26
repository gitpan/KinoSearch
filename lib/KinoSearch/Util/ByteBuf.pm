use strict;
use warnings;

package KinoSearch::Util::ByteBuf;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Util::ByteBuf

kino_ByteBuf*
new(class, sv)
    const classname_char *class;
    SV *sv;
CODE:
{
    STRLEN len;
    char *ptr = SvPV(sv, len);
    RETVAL = kino_BB_new_str(ptr, len);
    KINO_UNUSED_VAR(class);
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::ByteBuf - Lightweight scalar.

=head1 DESCRIPTION

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut
