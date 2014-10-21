package KinoSearch::Highlight::SimpleHTMLFormatter;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Highlight::Formatter );

BEGIN {
    __PACKAGE__->init_instance_vars(
        pre_tag  => '<strong>',
        post_tag => '</strong>',
    );
}

sub highlight {
    my ( $self, $text ) = @_;
    return "$self->{pre_tag}$text$self->{post_tag}";
}

1;

__END__

=head1 NAME

KinoSearch::Highlight::SimpleHTMLFormatter - surround highlight bits with tags

=head1 SYNOPSIS

    my $formatter = KinoSearch::Highlight::SimpleHTMLFormatter->new(
        pre_tag  => '<i>',
        post_tag => '</i>',
    );

    # returns "<i>foo</i>"
    my $highlighted = $formatter->highlight("foo");
    

=head1 DESCRIPTION

This subclass of
L<KinoSearch::Highlight::Formatter|KinoSearch::Highlight::Formatter>
highlights text by surrounding it with HTML "strong" tags.

=head1 METHODS

=head2 new

Constructor.  Takes hash-style params.

    my $formatter = KinoSearch::Highlight::SimpleHTMLFormatter->new(
        pre_tag =>  '*', # default: '<strong>'
        post_tag => '*', # default: '</strong>'
    );

=over

=item *

B<pre_tag> - a string which will be inserted immediately prior to the
highlightable text, typically to accentuate it.  If you don't want
highlighting, set both C<pre_tag> and C<post_tag> to C<''>.

=item *

B<post_tag> - a string which will be inserted immediately after the
highlightable text.

=back

=head1 COPYRIGHT

Copyright 2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.14.

=cut
