use strict;
use warnings;

package KinoSearch::Store::FSFileDes;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::FileDes );

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Store::FSFileDes

kino_FSFileDes*
new(class, path, mode)
    const classname_char *class;
    const char *path;
    const char *mode;
CODE:
    KINO_UNUSED_VAR(class);
    RETVAL = kino_FSFileDes_new(path, mode);
OUTPUT: RETVAL


__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Store::FSFileDes - File System FileDes

=head1 DESCRIPTION

File-System subclass of FileDes.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


