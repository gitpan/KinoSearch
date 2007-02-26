use strict;
use warnings;

package KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Analysis::Analyzer );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor params / members
        analyzers => undef,
        language  => undef,
    );
}

use KinoSearch::Analysis::LCNormalizer;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Analysis::Stemmer;

sub init_instance {
    my $self     = shift;
    my $language = $self->{language} = lc( $self->{language} );

    # create a default set of analyzers if language was specified
    if ( !defined $self->{analyzers} ) {
        confess("Must specify either 'language' or 'analyzers'")
            unless $language;
        $self->{analyzers} = [
            KinoSearch::Analysis::LCNormalizer->new( language => $language ),
            KinoSearch::Analysis::Tokenizer->new( language    => $language ),
            KinoSearch::Analysis::Stemmer->new( language      => $language ),
        ];
    }
}

sub analyze {
    my ( $self, $token_batch ) = @_;

    # iterate through each of the anayzers in order
    $token_batch = $_->analyze($token_batch) for @{ $self->{analyzers} };

    return $token_batch;
}

1;

__END__

=head1 NAME

KinoSearch::Analysis::PolyAnalyzer - Multiple analyzers in series.

=head1 SYNOPSIS

    my $analyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        language  => 'es',
    );
    
    # or...

    my $lc_normalizer = KinoSearch::Analysis::LCNormalizer->new;
    my $tokenizer     = KinoSearch::Analysis::Tokenizer->new;
    my $stemmer       = KinoSearch::Analysis::Stemmer->new( language => 'en' );
    my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
        analyzers => [
            $lc_normalizer,
            $whitespace_tokenizer,
            $stemmer,
        ],
    );

=head1 DESCRIPTION

A PolyAnalyzer is a series of Analyzers -- objects which inherit from
L<KinoSearch::Analysis::Analyzer> -- each of which will be called upon to
"analyze" text in turn.  You can either provide the Analyzers yourself, or you
can specify a supported language, in which case a PolyAnalyzer consisting of
an L<LCNormalizer|KinoSearch::Analysis::LCNormalizer>, a
L<Tokenizer|KinoSearch::Analysis::Tokenizer>, and a
L<Stemmer|KinoSearch::Analysis::Stemmer> will be generated for you.  

Supported languages:

    en => English,
    da => Danish,
    de => German,
    es => Spanish,
    fi => Finnish,
    fr => French,
    it => Italian,
    nl => Dutch,
    no => Norwegian,
    pt => Portuguese,
    ru => Russian,
    sv => Swedish,


=head1 METHODS 

=head2 new()

Constructor.   Takes two possible hash-style parameters.  If the parameter
C<analyzers> is specified, it will override C<language> and no attempt will be
made to generate a default set of Analyzers.

=over

=item

B<language> - Must be an ISO code from the list of supported languages.

=item

B<analyzers> - Must be an arrayref.  Each element in the array must inherit
from KinoSearch::Analysis::Analyzer.  The order of the analyzers matters.
Don't put a Stemmer before a Tokenizer (can't stem whole documents or
paragraphs -- just individual words), or a Stopalizer after a Stemmer (stemmed
words, e.g. "themselv", will not appear in a stoplist).  In general, the
sequence should be: normalize, tokenize, stopalize, stem.

=back

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=cut

