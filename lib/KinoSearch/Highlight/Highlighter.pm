package KinoSearch::Highlight::Highlighter;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars(
    # constructor params / members
    excerpt_field  => undef,
    analyzer       => undef,
    terms          => [],
    excerpt_length => 200,
    pre_tag        => '<strong>',
    post_tag       => '</strong>',
    token_re       => qr/\b\w+(?:'\w+)?\b/,

    # members
    limit => undef,
);

__PACKAGE__->ready_get_set(qw( terms ));

sub init_instance {
    my $self = shift;
    croak("Missing required arg 'excerpt_field'")
        unless defined $self->{excerpt_field};

    # scoring window is 1.66 * excerpt_length, with the loc in the middle
    $self->{limit} = int( $self->{excerpt_length} / 3 );
}

sub generate_excerpt {
    my ( $self, $doc ) = @_;
    my $excerpt_length    = $self->{excerpt_length};
    my $limit             = $self->{limit};
    my $token_re          = $self->{token_re};
    my $additional_offset = 0;

    # retrieve the text from the chosen field
    my $field       = $doc->get_field( $self->{excerpt_field} );
    my $text        = $field->get_value;
    my $text_length = bytes::length $text;
    return '' unless $text_length;

    # determine the rough boundaries of the excerpt
    my ( $starts, $ends ) = $self->_starts_and_ends($field);
    my $best_location = $self->_calc_best_location($starts);
    my $top           = $best_location - $limit;

    # expand the excerpt if the best location is near the end
    $top =
          $text_length - $excerpt_length < $top
        ? $text_length - $excerpt_length
        : $top;

    # if the best starting point is the very beginning, cool
    if ( $top <= 0 ) {
        $top = 0;
    }
    else {
        # ... otherwise, try to start the excerpt at a sentence boundary
        if ($text =~ m/
                \A
                (
                \C{$top}
                \C{0,$limit}?
                \.\s*
                )
                /xsm
            )
        {
            $top = bytes::length($1);
        }
        # no sentence boundary, so we'll need an ellipsis
        else {
            # skip past possible partial tokens, prepend an ellipsis
            if ($text =~ s/
                \A
                (
                \C{$top}       # up to the top
                \C{0,$limit}?  # don't go outside the window
                $token_re      # match possible partial token
                .*?            # ... and any junk following that token
                )
                (?=$token_re)  # just before the start of a full token...
                /$1... /xsm    # ... insert an ellipsis
                )
            {
                $top = bytes::length($1);
                $additional_offset += 4;    # three dots and a space
            }
        }
    }

    # remove possible partial tokens from the end of the excerpt
    $text = bytes::substr( $text, $top, $excerpt_length + 1 );
    if ( bytes::length($text) > $excerpt_length ) {
        my $extra_char = chop $text;
        # if the extra char wasn't part of a token, we aren't splitting one
        if ( $extra_char =~ $token_re ) {
            $text =~ s/$token_re$//;    # if this is unsuccessful, that's fine
        }
    }

    # if the excerpt doesn't end with a full stop, end with an an ellipsis
    if ( $text !~ /\.\s*$/s ) {
        $text =~ s/\W+$//;
        while ( bytes::length($text) + 4 > $excerpt_length ) {
            my $extra_char = chop $text;
            if ( $extra_char =~ $token_re ) {
                $text =~ s/\W+$token_re$//;    # if unsuccessful, that's fine
            }
            $text =~ s/\W+$//;
        }
        $text .= ' ...';
    }

    # remap locations now that we know the starting and ending bytes
    $text_length = bytes::length($text);
    my @relative_starts = map { $_ + $additional_offset - $top } @$starts;
    my @relative_ends   = map { $_ + $additional_offset - $top } @$ends;

    # get rid of pairs with at least one member outside the text
    while ( @relative_starts and $relative_starts[0] < 0 ) {
        shift @relative_starts;
        shift @relative_ends;
    }
    while ( @relative_ends and $relative_ends[-1] > $text_length ) {
        pop @relative_starts;
        pop @relative_ends;
    }

    # insert highlighting tags
    if ( bytes::length $self->{pre_tag} or bytes::length $self->{post_tag} ) {
        my $pre_tag  = $self->{pre_tag};
        my $post_tag = $self->{post_tag};
        # traverse the excerpt from back to front, inserting highlight tags
        while (@relative_starts) {
            my $loc = pop @relative_ends;
            $text =~ s/^(\C{$loc})/$1$post_tag/;
            $loc = pop @relative_starts;
            $text =~ s/^(\C{$loc})/$1$pre_tag/;
        }
    }

    return $text;
}

=for comment
Find all points in the text where a relevant term begins and ends.  For terms
that are part of a phrase, only include points that are part of the phrase.

=cut

sub _starts_and_ends {
    my ( $self, $field ) = @_;
    my ( @starts, @ends );
    my %done;

TERM: for my $term ( @{ $self->{terms} } ) {
        if ( a_isa_b( $term, 'KinoSearch::Index::Term' ) ) {
            my $term_text = $term->get_text;

            next TERM if $done{$term_text};
            $done{$term_text} = 1;

            # add all starts and ends
            my $term_vector = $field->term_vector($term_text);
            next TERM unless defined $term_vector;
            push @starts, @{ $term_vector->get_start_offsets };
            push @ends,   @{ $term_vector->get_end_offsets };
        }
        # intersect positions for phrase terms
        else {
            # if not a Term, it's an array of Terms representing a phrase
            my @term_texts = map { $_->get_text } @$term;

            my $phrase_text = join( ' ', @term_texts );
            next TERM if $done{$phrase_text};
            $done{$phrase_text} = 1;

            my $posit_vec    = KinoSearch::Util::BitVector->new;
            my @term_vectors = map { $field->term_vector($_) } @term_texts;
            my $i            = 0;
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
                    $posit_vec->logical_and($other_posit_vec);
                }
                $i++;
            }

            # add only those starts/ends that belong to a valid position
            $i = 0;
            for my $tv (@term_vectors) {
                my @valid_positions
                    = map { $_ + $i } @{ $posit_vec->to_arrayref };
                my $tv_positions = $tv->get_positions;
                my $tv_starts    = $tv->get_start_offsets;
                my $tv_ends      = $tv->get_end_offsets;
                my $next_valid   = shift @valid_positions;
                for my $j ( 0 .. $#$tv_positions ) {
                    next unless $tv_positions->[$j] == $next_valid;
                    push @starts, $tv_starts->[$j];
                    push @ends,   $tv_ends->[$j];
                    last unless ( $next_valid = shift @valid_positions );
                }
                $i++;
            }
        }
    }

    # sort and return
    @starts = sort { $a <=> $b } @starts;
    @ends   = sort { $a <=> $b } @ends;
    return ( \@starts, \@ends );
}

=for comment 
Select the byte address representing the greatest keyword density.  Because
the algorithm counts bytes rather than characters, it will degrade if the
number of bytes per character is larger than 1.

=cut

sub _calc_best_location {
    my ( $self, $starts ) = @_;
    my $window = $self->{limit} * 2;

    # if there aren't any keywords, take the excerpt from the top of the text
    return 0 unless @$starts;

    my %locations = map { ( $_ => 0 ) } @$starts;

    # if another keyword is in close proximity, add to the loc's score
    for my $loc_index ( 0 .. $#$starts ) {
        # only score positions that are in range
        my $location        = $starts->[$loc_index];
        my $other_loc_index = $loc_index - 1;
        while ( $other_loc_index > 0 ) {
            my $diff = $location - $starts->[$other_loc_index];
            last if $diff > $window;
            $locations{$location} += ( 1 / ( 1 + log($diff) ) );
            --$other_loc_index;
        }
        $other_loc_index = $loc_index + 1;
        while ( $other_loc_index <= $#$starts ) {
            my $diff = $starts->[$other_loc_index] - $location;
            last if $diff > $window;
            $locations{$location} += ( 1 / ( 1 + log($diff) ) );
            ++$other_loc_index;
        }
    }

    # return the highest scoring position
    return ( sort { $locations{$b} <=> $locations{$a} } keys %locations )[0];
}

1;

__END__

=head1 NAME

KinoSearch::Highlight::Highlighter - create and highlight excerpts

=head1 SYNOPSIS

    my $highlighter = KinoSearch::Highlight::Highlighter->new(
        excerpt_field  => 'bodytext',
    );
    $hits->create_excerpts( highlighter => $highlighter );

=head1 DESCRIPTION

KinoSearch's Highlighter can be used to select a relevant snippet from a
document, and to surround search terms with highlighting tags.  It handles
both stems and phrases correctly and efficiently, using special-purpose data
generated at index-time.  

=head1 METHODS

=head2 new

    my $highlighter = KinoSearch::Highlight::Highlighter->new(
        excerpt_field  => 'bodytext', # required
        excerpt_length => 150,        # default: 200
        pre_tag        => '*',        # default: '<strong>'
        post_tag       => '*',        # default: '</strong>',
    );

Constructor.  Takes hash-style parameters: 

=over

=item *

B<excerpt_field> - the name of the field from which to draw the excerpt.

=item *

B<excerpt_length> - the length of the excerpt, in I<bytes>.  This should
probably use characters as a unit instead of bytes, and the behavior is likely
to change in the future.

=item *

B<pre_tag> - a string which will be inserted immediately prior to any keyword
in the excerpt, typically to accentuate it.  If you don't want highlighting,
set both C<pre_tag> and C<post_tag> to C<''>.

=item *

B<post_tag> - a string which will be inserted immediately after any keyword in
the excerpt.

=back

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.06.

=cut
