use strict;
use warnings;

package KinoSearch::Analysis::Tokenizer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Analysis::Analyzer );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        token_re => qr/\w+(?:'\w+)*/,
    );
}

use KinoSearch::Analysis::Token;
use KinoSearch::Analysis::TokenBatch;

sub analyze {
    my ( $self, $batch ) = @_;
    my $token_re  = $self->{token_re};
    my $new_batch = KinoSearch::Analysis::TokenBatch->new;

    # alias input to $_
    while ( my $token = $batch->next ) {
        for ( $token->get_text ) {
            # accumulate token start_offsets and end_offsets
            my ( @starts, @ends );
            while (/$token_re/g) {
                push @starts, $-[0];
                push @ends,   $+[0];
            }

            # add the new tokens to the batch
            $new_batch->add_many_tokens( $_, \@starts, \@ends );
        }
    }

    return $new_batch;
}

1;

__END__

__POD__

=head1 NAME

KinoSearch::Analysis::Tokenizer - Customizable tokenizing.

=head1 SYNOPSIS

    my $whitespace_tokenizer
        = KinoSearch::Analysis::Tokenizer->new( token_re => qr/\S+/, );

    # or...
    my $word_char_tokenizer
        = KinoSearch::Analysis::Tokenizer->new( token_re => qr/\w+/, );

    # or...
    my $apostrophising_tokenizer = KinoSearch::Analysis::Tokenizer->new;

    # then... once you have a tokenizer, put it into a PolyAnalyzer
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        analyzers => [ $lc_normalizer, $word_char_tokenizer, $stemmer ], );


=head1 DESCRIPTION

Generically, "tokenizing" is a process of breaking up a string into an array
of "tokens".

    # before:
    my $string = "three blind mice";

    # after:
    @tokens = qw( three blind mice );

KinoSearch::Analysis::Tokenizer decides where it should break up the text
based on the value of C<token_re>.

    # before:
    my $string = "Eats, Shoots and Leaves.";

    # tokenized by $whitespace_tokenizer
    @tokens = qw( Eats, Shoots and Leaves. );

    # tokenized by $word_char_tokenizer
    @tokens = qw( Eats Shoots and Leaves   );

=head1 METHODS

=head2 new

    # match "it's" as well as "it" and "O'Henry's" as well as "Henry"
    my $token_re = qr/
            \w+       # Match word chars.
            (?:       # Group, but don't capture...
               '\w+   # ... an apostrophe plus word chars.
            )*        # Matching the apostrophe group is optional.
        /xsm;
    my $tokenizer = KinoSearch::Analysis::Tokenizer->new(
        token_re => $token_re, # default: what you see above
    );

Constructor.  Takes one hash style parameter.

=over

=item *

B<token_re> - must be a pre-compiled regular expression matching one token.

=back

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=cut
