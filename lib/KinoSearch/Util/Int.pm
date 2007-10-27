use strict;
use warnings;

package KinoSearch::Util::Int;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Util::Int

kino_Int*
new(class_name, value)
    const classname_char *class_name;
    chy_u64_t value;
CODE:
    CHY_UNUSED_VAR(class_name);
    RETVAL = kino_Int_new(value);
OUTPUT: RETVAL

NV
get_value(self)
    kino_Int *self;
CODE:
    RETVAL = self->value;
OUTPUT: RETVAL
    
__POD__

=begin devdocs

=head1 PRIVATE CLASS 

KinoSearch::Util::Int - an integer.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


