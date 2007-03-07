use strict;
use warnings;

package KinoSearch::Store::RAMFileDes;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::FileDes );

use KinoSearch::Util::ByteBuf;

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Store::RAMFileDes

kino_RAMFileDes*
new(class, path)
    const classname_char *class;
    const char *path;
CODE:
    KINO_UNUSED_VAR(class);
    RETVAL = kino_RAMFileDes_new(path);
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_RAMFileDes *self;
ALIAS:
    get_len = 2
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = newSViv(self->len);
             break;
    
    END_SET_OR_GET_SWITCH
}

kino_ByteBuf*
contents(self)
    kino_RAMFileDes *self;
CODE:
    RETVAL = Kino_RAMFileDes_Contents(self);
OUTPUT: RETVAL

__POD__


=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Store::RAMFileDes - in-memory FileDes

=head1 DESCRIPTION

RAM-based subclass of FileDes.  "Files" pointed to by RAMFileDes objects are
implemented using ragged arrays.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut

