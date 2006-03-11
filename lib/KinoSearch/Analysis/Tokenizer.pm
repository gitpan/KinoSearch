package KinoSearch::Analysis::Tokenizer;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Analysis::Analyzer );

use KinoSearch::Analysis::TokenBatch;

our %instance_vars = __PACKAGE__->init_instance_vars(

    # constructor params / members
    token_re => undef,    # regex for a single token

    # members
    separator_re  => undef,    # regex for separations between tokens
    tokenizing_re => undef,    # regex optimized for lexing
);

sub init_instance {
    my $self = shift;

    # supply defaults if token_re wasn't specified
    if ( !defined $self->{token_re} ) {
        $self->{token_re}     = qr/\b\w+(?:'\w+)?\b/;
        $self->{separator_re} = qr/\W*/;
    }

    # if user-defined token_re...
    if ( !defined $self->{separator_re} ) {

        # define separator using lookahead
        $self->{separator_re} = qr/
            .*?                    # match up to...
            (?=                    # but not including...
                $self->{token_re}  # a token, 
                |\z                # or the end of the string
            )/xsm;
        $self->{tokenizing_re} = qr/
            ($self->{token_re})           # capture token to $1
            (.*?                          # capture separator to $2
                (?=
                    $self->{token_re}
                    |\z
                )
            )/xsm;
    }

    # if internally defined token_re and separator_re...
    if ( !defined $self->{tokenizing_re} ) {
        # use slightly more efficient non-lookahead tokenizing_re scheme
        $self->{tokenizing_re} = qr/
            ($self->{token_re})           # capture token to $1
            ($self->{separator_re})       # capture separator to $2
            /xsm;
    }
}

sub analyze {
    my ( $self, $token_batch ) = @_;
    my $tokenizing_re = $self->{tokenizing_re};

    my $new_token_batch = KinoSearch::Analysis::TokenBatch->new;
    my @raw_elems;

    # alias input to $_
    while ( $token_batch->next ) {
        local $_ = $token_batch->get_text;

        # set the pos for input to the start of the first token
        pos = 0;
        m/$self->{separator_re}/g;

        my $last_pos = 0;
        # lex through input, capturing tokens and recording positional data
        while (m/$tokenizing_re/g) {
            my $pos = pos;
            push @raw_elems, ( $1, $last_pos, $pos - bytes::length($2) );
            $last_pos = $pos;
        }
    }
    $new_token_batch->add_many_tokens( \@raw_elems );

    return $new_token_batch;
}

1;

__END__

=head1 NAME

KinoSearch::Analysis::Tokenizer - customizable tokenizing 

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

=head1 CONSTRUCTOR

=head2 new

    my $tokenizer = KinoSearch::Analysis::Tokenizer->new(
        token_re => $matches_one_token, );

Construct a Tokenizer object.  

B<token_re> must be a pre-compiled regular expression matching one token.  It
must not use any capturing parentheses, though non-capturing parentheses are
fine:

    # match "O'Henry" as well as "Henry" and "it's" as well as "it"
    my $token_re = qr/
            \b        # start with a word boundary
            \w+       # Match word chars.
            (?:       # Group, but don't capture...
               '\w+   # ... an apostrophe plus word chars.
            )?        # Matching the apostrophe group is optional.
            \b        # end with a word boundary
        /xsm;
    my $apostrophizing_tokenizer
        = KinoSearch::Analysis::Tokenizer->new( token_re => $token_re, );

Incidentally, the above token_re is the default value.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.08.

=cut
