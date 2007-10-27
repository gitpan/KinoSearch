use strict;
use warnings;

package KinoSearch::Highlight::Highlighter;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # members
    default_encoder   => undef,
    default_formatter => undef,
    specs             => undef,
    terms             => undef,
    limit             => undef,
    token_re          => qr/\b\w+(?:'\w+)?\b/,
);

BEGIN { __PACKAGE__->ready_get_set(qw( terms )) }

use KinoSearch::Highlight::SimpleHTMLFormatter;
use KinoSearch::Highlight::SimpleHTMLEncoder;

sub init_instance {
    my $self = shift;
    $self->{specs} = [];
    $self->{terms} = [];

    # create shared default encoder and formatter
    $self->{default_encoder} = KinoSearch::Highlight::SimpleHTMLEncoder->new;
    $self->{default_formatter}
        = KinoSearch::Highlight::SimpleHTMLFormatter->new(
        pre_tag  => '<strong>',
        post_tag => '</strong>',
        );
}

my %add_spec_defaults = (
    field          => undef,
    excerpt_length => 200,
    formatter      => undef,
    encoder        => undef,
    name           => undef,
);

sub add_spec {
    my $self = shift;
    confess kerror() unless verify_args( \%add_spec_defaults, @_ );
    my %spec = ( %add_spec_defaults, @_ );

    confess("Missing required param 'field'")
        unless defined $spec{field};

    # assume HTML
    if ( !defined $spec{encoder} ) {
        $spec{encoder} = $self->{default_encoder};
    }
    if ( !defined $spec{formatter} ) {
        $spec{formatter} = $self->{default_formatter};
    }

    # scoring window is 1.66 * excerpt_length, with the loc in the middle
    $spec{limit} = int( $spec{excerpt_length} / 3 );

    # use field name as key unless specified
    $spec{name} = $spec{field} unless defined $spec{name};

    push @{ $self->{specs} }, \%spec;
}

sub generate_excerpts {
    my ( $self, $doc, $doc_vector ) = @_;

    # create an excerpt for each spec
    my %excerpts;
    for my $spec ( @{ $self->{specs} } ) {
        $excerpts{ $spec->{name} }
            = $self->_gen_excerpt( $doc, $doc_vector, $spec );
    }

    return \%excerpts;
}

sub _gen_excerpt {
    my ( $self, $doc, $doc_vector, $spec ) = @_;
    my $excerpt_field  = $spec->{field};
    my $excerpt_length = $spec->{excerpt_length};
    my $limit          = $spec->{limit};
    my $token_re       = $self->{token_re};

    # retrieve the text from the chosen field
    my $text = $doc->{$excerpt_field};
    return unless defined $text;
    my $text_length = length $text;
    my $orig_length = $text_length;
    return '' unless $text_length;

    # determine the rough boundaries of the excerpt
    my $posits = $self->_starts_and_ends( $doc_vector, $excerpt_field );
    my $best_location = $self->_calc_best_location( $posits, $limit );
    my $top = $best_location - $limit;

    # expand the excerpt if the best location is near the end
    $top
        = $text_length - $excerpt_length < $top
        ? $text_length - $excerpt_length
        : $top;

    # if the best starting point is the very beginning, cool...
    if ( $top <= 0 ) {
        $top = 0;
    }
    # ... otherwise ...
    else {
        # lop off $top characters
        $text = substr( $text, $top );

        # try to start the excerpt at a sentence boundary
        if ($text =~ s/
                \A
                (
                .{0,$limit}?
                \.\s+
                )
                //xsm
            )
        {
            $top += length($1);
        }
        # no sentence boundary, so we'll need an ellipsis
        else {
            # skip past possible partial tokens, prepend an ellipsis
            if ($text =~ s/
                \A
                (
                .{0,$limit}?  # don't go outside the window
                $token_re      # match possible partial token
                .*?            # ... and any junk following that token
                )
                (?=$token_re)  # just before the start of a full token...
                /... /xsm    # ... insert an ellipsis
                )
            {
                $top += length($1);
                $top -= 4    # three dots and a space
            }
        }
    }

    # remove possible partial tokens from the end of the excerpt
    $text = substr( $text, 0, $excerpt_length + 1 );
    if ( length($text) > $excerpt_length ) {
        my $extra_char = chop $text;
        # if the extra char wasn't part of a token, we aren't splitting one
        if ( $extra_char =~ $token_re ) {
            $text =~ s/$token_re$//;    # if this is unsuccessful, that's fine
        }
    }

    # if the excerpt doesn't end with a full stop, end with an an ellipsis
    if ( $orig_length > length($text) and $text !~ /\.\s*\Z/xsm ) {
        $text =~ s/\W+\Z//xsm;
        while ( length($text) + 4 > $excerpt_length ) {
            my $extra_char = chop $text;
            if ( $extra_char =~ $token_re ) {
                $text =~ s/\W+$token_re\Z//xsm; # if unsuccessful, that's fine
            }
            $text =~ s/\W+\Z//xsm;
        }
        $text .= ' ...';
    }

    # remap locations now that we know the starting and ending bytes
    $text_length = length($text);
    my @relative_starts = map { $_->[0] - $top } @$posits;
    my @relative_ends   = map { $_->[1] - $top } @$posits;

    # get rid of pairs with at least one member outside the text
    while ( @relative_starts and $relative_starts[0] < 0 ) {
        shift @relative_starts;
        shift @relative_ends;
    }
    while ( @relative_ends and $relative_ends[-1] > $text_length ) {
        pop @relative_starts;
        pop @relative_ends;
    }

    # insert highlight tags
    my $formatter   = $spec->{formatter};
    my $encoder     = $spec->{encoder};
    my $output_text = '';
    my ( $start, $end, $last_start, $last_end ) = ( undef, undef, 0, 0 );
    while (@relative_starts) {
        $end   = shift @relative_ends;
        $start = shift @relative_starts;
        $output_text .= $encoder->encode(
            substr( $text, $last_end, $start - $last_end ) );
        $output_text .= $formatter->highlight(
            $encoder->encode( substr( $text, $start, $end - $start ) ) );
        $last_end = $end;
    }
    $output_text .= $encoder->encode( substr( $text, $last_end ) );

    return $output_text;
}

=for comment
Find all points in the text where a relevant term begins and ends.  For terms
that are part of a phrase, only include points that are part of the phrase.

=cut

sub _starts_and_ends {
    my ( $self, $doc_vector, $excerpt_field ) = @_;
    my @posits;
    my %done;

TERM: for my $term ( @{ $self->{terms} } ) {
        if ( a_isa_b( $term, 'KinoSearch::Index::Term' ) ) {
            next if $term->get_field ne $excerpt_field;
            my $term_text = $term->get_text;

            next TERM if $done{$term_text};
            $done{$term_text} = 1;

            # add all starts and ends
            my $term_vector
                = $doc_vector->term_vector( $excerpt_field, $term_text );
            next TERM unless defined $term_vector;
            my $starts = $term_vector->get_start_offsets;
            my $ends   = $term_vector->get_end_offsets;
            while (@$starts) {
                push @posits, [ shift @$starts, shift @$ends, 1 ];
            }
        }
        # intersect positions for phrase terms
        else {
            # if not a Term, it's an array of Terms representing a phrase
            next if $term->[0]->get_field ne $excerpt_field;
            my @term_texts = map { $_->get_text } @$term;

            my $phrase_text = join( ' ', @term_texts );
            next TERM if $done{$phrase_text};
            $done{$phrase_text} = 1;

            my $posit_vec = KinoSearch::Util::BitVector->new;
            my @term_vectors
                = map { $doc_vector->term_vector( $excerpt_field, $_ ) }
                @term_texts;

            # make sure all terms are present
            next TERM unless scalar @term_vectors == scalar @term_texts;

            my $i = 0;
            for my $tv (@term_vectors) {
                # one term missing, ergo no phrase
                next TERM unless defined $tv;
                if ( $i == 0 ) {
                    $posit_vec->set( @{ $tv->get_positions } );
                }
                else {
                    # filter positions using logical "and"
                    my $other_posit_vec = KinoSearch::Util::BitVector->new;
                    $other_posit_vec->set(
                        grep    { $_ >= 0 }
                            map { $_ - $i } @{ $tv->get_positions }
                    );
                    $posit_vec->AND($other_posit_vec);
                }
                $i++;
            }

            # add only those starts/ends that belong to a valid position
            my $tv_start_positions = $term_vectors[0]->get_positions;
            my $tv_starts          = $term_vectors[0]->get_start_offsets;
            my $tv_end_positions   = $term_vectors[-1]->get_positions;
            my $tv_ends            = $term_vectors[-1]->get_end_offsets;
            $i = 0;
            my $j                = 0;
            my $last_token_index = $#term_vectors;
            for my $valid_position ( @{ $posit_vec->to_arrayref } ) {

                while ( $i <= $#$tv_start_positions ) {
                    last if ( $tv_start_positions->[$i] >= $valid_position );
                    $i++;
                }
                $valid_position += $last_token_index;
                while ( $j <= $#$tv_end_positions ) {
                    last if ( $tv_end_positions->[$j] >= $valid_position );
                    $j++;
                }
                push @posits,
                    [ $tv_starts->[$i], $tv_ends->[$j], scalar @$term ];
                $i++;
                $j++;
            }
        }
    }
    @posits = sort { $a->[0] <=> $b->[0] || $b->[1] <=> $a->[1] } @posits;
    my @unique;
    my $last = ~0;
    for (@posits) {
        push @unique, $_ if $_->[0] != $last;
        $last = $_->[0];
    }
    return \@unique;
}

# Select the character position representing the greatest keyword density.
sub _calc_best_location {
    my ( $self, $posits, $limit ) = @_;
    my $window = $limit * 2;

    # if there aren't any keywords, take the excerpt from the top of the text
    return 0 unless @$posits;

    my %locations = map { ( $_->[0] => 0 ) } @$posits;

    # if another keyword is in close proximity, add to the loc's score
    for my $loc_index ( 0 .. $#$posits ) {
        # only score positions that are in range
        my $location        = $posits->[$loc_index][0];
        my $other_loc_index = $loc_index - 1;
        while ( $other_loc_index > 0 ) {
            my $diff = $location - $posits->[$other_loc_index][0];
            last if $diff > $window;
            my $num_tokens_at_pos = $posits->[$other_loc_index][2];
            $locations{$location}
                += ( 1 / ( 1 + log($diff) ) ) * $num_tokens_at_pos;
            --$other_loc_index;
        }
        $other_loc_index = $loc_index + 1;
        while ( $other_loc_index <= $#$posits ) {
            my $diff = $posits->[$other_loc_index] - $location;
            last if $diff > $window;
            my $num_tokens_at_pos = $posits->[$other_loc_index][2];
            $locations{$location}
                += ( 1 / ( 1 + log($diff) ) ) * $num_tokens_at_pos;
            ++$other_loc_index;
        }
    }

    # return the highest scoring position
    return ( sort { $locations{$b} <=> $locations{$a} } keys %locations )[0];
}

1;

__END__

=head1 NAME

KinoSearch::Highlight::Highlighter - Create and highlight excerpts.

=head1 SYNOPSIS

    my $highlighter = KinoSearch::Highlight::Highlighter->new;
    $highlighter->add_spec( field => 'body' );

    $hits->create_excerpts( highlighter => $highlighter );

=head1 DESCRIPTION

KinoSearch's Highlighter can be used to select relevant snippets from a
document, and to surround search terms with highlighting tags.  It handles
both stems and phrases correctly and efficiently, using special-purpose data
generated at index-time.  

=head1 METHODS

=head2 new

    my $highlighter = KinoSearch::Highlight::Highlighter->new;

Constructor.  Takes no arguments.

=head2 add_spec

    $highlighter->add_spec(
        field          => 'content',   # required
        excerpt_length => 150,         # default: 200
        formatter      => $formatter,  # default: SimpleHTMLFormatter
        encoder        => $encoder,    # default: SimpleHTMLEncoder
        name           => 'blurb'      # default: value of field param
    );

Add a spec for a single highlighted excerpt.  Takes hash-style parameters: 

=over

=item *

B<field> - the name of the field from which to draw the excerpt.  The field
must be C<vectorized> (which is the default -- see
L<FieldSpec|KinoSearch::FieldSpec>).

=item *

B<excerpt_length> - the maximum length of the excerpt, in characters.

=item *

B<formatter> - an object which isa L<KinoSearch::Highlight::Formatter>.  Used
to perform the actual highlighting.

=item *

B<encoder> - an object which isa L<KinoSearch::Highlight::Encoder>.  All
excerpt text gets passed through the encoder, including highlighted terms.  By
default, this is a SimpleHTMLEncoder, which encodes HTML entities.

=item *

B<name> - the key which will identify the excerpt in the excerpts hash.
Multiple excerpts with different specifications can be created from the same
source field using different values for C<name>.

=back

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
