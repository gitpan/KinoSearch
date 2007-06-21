use strict;
use warnings;

package KinoSearch::Highlight::Formatter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = ();

sub highlight_term { shift->abstract_death }

1;

__END__

=head1 NAME

KinoSearch::Highlight::Formatter - Format highlighted bits within excerpts.

=head1 SYNOPSIS

    # abstract base class

=head1 DESCRIPTION

Formatter objects serve one purpose: they highlight pieces of text within an
excerpt.  The text might be a single term, or it might be a phrase.  

=head1 METHODS

=head2 highlight

    my $highlighted = $formatter->highlight($text);

Abstract method.  Highlight text -- by surrounding it with asterisks, html
"strong" tags, etc.

=head1 COPYRIGHT

Copyright 2006-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
