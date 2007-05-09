use strict;
use warnings;

package KinoSearch::Highlight::Encoder;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

sub encode { shift->abstract_death }

1;

__END__

=head1 NAME

KinoSearch::Highlight::Encoder - Encode excerpted text.

=head1 SYNOPSIS

    # abstract base class

=head1 DESCRIPTION

Encoder objects are invoked by Highlighter objects for every piece of text
that makes it into an excerpt.  The archetypal implementation is
L<KinoSearch::Highlight::SimpleHTMLEncoder>.

=head1 METHODS

=head2 encode

    my $encoded = $encoder->encode($text);


=head1 COPYRIGHT

Copyright 2006-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
