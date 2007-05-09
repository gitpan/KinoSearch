use strict;
use warnings;

package KinoSearch::Highlight::SimpleHTMLEncoder;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

use HTML::Entities qw( encode_entities );

sub encode { return encode_entities( $_[1] ) }

1;

__END__

=head1 NAME

KinoSearch::Highlight::SimpleHTMLEncoder - Encode HTML entities.

=head1 SYNOPSIS

    # returns '&quot;Hey, you!&quot;'
    my $encoded = $encoder->encode('"Hey, you!"');

=head1 DESCRIPTION

Implementation of L<KinoSearch::Highlight::Encoder> which encodes HTML
entities.  

=head1 COPYRIGHT

Copyright 2006-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
