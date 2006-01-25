package KinoSearch::Analysis::Tokenizer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Analysis::Analyzer );

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
        $self->{token_re}     = qr/\w+(?:'\w+)?/;
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
    my ( $self, $field ) = @_;
    my $tokenizing_re = $self->{tokenizing_re};
    my ( @tokens, @start_offsets, @end_offsets );

    # use the first element in the terms array as input
    my $terms = $field->get_terms;

    # alias input to $_
    for ( $terms->[0] ) {

        # if the field content is an empty string, bail out
        return unless bytes::length($_);

        # set the pos for input to the start of the first token
        pos = 0;
        m/$self->{separator_re}/g;

        my $last_pos = 0;
        push @start_offsets, pos;

        # lex through input, capturing tokens and recording positional data
        while (m/$tokenizing_re/g) {
            push @tokens,        $1;
            push @start_offsets, pos;
            push @end_offsets,   pos() - bytes::length($2);
        }

        # the last loop will always record 1 extra start, so truncate
        $#start_offsets = $#tokens;
    }

    $field->set_tokenbatch( \@tokens, \@start_offsets, \@end_offsets );
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
            \w+       # Match word chars.
            (?:       # Group, but don't capture...
               '\w+   # ... an apostrophe plus word chars.
            )?        # Matching the apostrophe group is optional.
        /xsm;
    my $apostrophizing_tokenizer
        = KinoSearch::Analysis::Tokenizer->new( token_re => $token_re, );

Incidentally, the above token_re is the default value.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_05.

=cut
