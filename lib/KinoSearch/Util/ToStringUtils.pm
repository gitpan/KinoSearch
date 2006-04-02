package KinoSearch::Util::ToStringUtils;
use strict;
use warnings;
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

=head1 NAME

KinoSearch::Util::ToStringUtils - common routines which aid stringification

=head1 DESCRIPTION

Provide functions which help with to_string.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.09.

=end devdocs
=cut
