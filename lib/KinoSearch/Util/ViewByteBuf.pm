use strict;
use warnings;

package KinoSearch::Util::ViewByteBuf;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::ByteBuf );

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Util::ViewByteBuf

kino_ViewByteBuf*
new(class, sv)
    const classname_char *class;
    SV *sv;
CODE:
{
    STRLEN len;
    char *ptr = SvPV(sv, len);
    char *dupe = KINO_MALLOCATE(len + 1, char);
    dupe[len] = '\0';
    memcpy(dupe, ptr, len);
    RETVAL = kino_ViewBB_new(dupe, len);
    KINO_UNUSED_VAR(class);
}
OUTPUT: RETVAL

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::ViewByteBuf - A ByteBuf that doesn't own its string.

=head1 DESCRIPTION

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut
