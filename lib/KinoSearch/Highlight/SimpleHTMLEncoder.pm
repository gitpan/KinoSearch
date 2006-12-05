package KinoSearch::Highlight::SimpleHTMLEncoder;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars();
}

sub encode {
    my $text = $_[1];
    for ($text) {
        s/&/&amp;/g;
        s/"/&quot;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
    }
    return $text;
}

1;

__END__

=head1 NAME

KinoSearch::Highlight::SimpleHTMLEncoder - encode a few HTML entities

=head1 SYNOPSIS

    # returns '&quot;Hey, you!&quot;'
    my $encoded = $encoder->encode('"Hey, you!"');

=head1 DESCRIPTION

Implemetation of L<KinoSearch::Highlight::Encoder> which encodes HTML
entities.  Currently, this module takes a minimal approach, encoding only
'<', '>', '&', and '"'.  That is likely to change in the future.

=head1 COPYRIGHT

Copyright 2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.15.

=cut
