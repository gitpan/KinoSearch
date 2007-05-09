use strict;
use warnings;

package KinoSearch::Index::TermStepper;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Stepper );

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Index::TermStepper

kino_TermStepper*
new(class_name, field, index_interval, is_index);
    const classname_char *class_name;
    kino_ByteBuf field;
    chy_u32_t index_interval;
    chy_bool_t is_index;
CODE:
    RETVAL = kino_TermStepper_new(&field, index_interval, is_index);
    CHY_UNUSED_VAR(class_name);
OUTPUT: RETVAL


__POD__

=begin devdocs

=head1 PRIVATE CLASS 

KinoSearch::Index::TermStepper - Stepper for reading/writing Lexicons.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


