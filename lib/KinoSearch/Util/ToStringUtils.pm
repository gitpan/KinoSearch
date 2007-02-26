use strict;
use warnings;

package KinoSearch::Util::ToStringUtils;
use KinoSearch::Util::ToolSet;
use base qw( Exporter );

our @EXPORT_OK = qw( boost_to_string );

# return a stringified numerical boost if it actually does anything.
sub boost_to_string {
    my $boost = shift;
    return $boost == 1 ? '' : "^$boost";
}

1;

__END__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Util::ToStringUtils - Common routines which aid stringification.

=head1 DESCRIPTION

Provide functions which help with to_string.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut
