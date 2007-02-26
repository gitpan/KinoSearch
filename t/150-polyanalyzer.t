use strict;
use warnings;

use Test::More tests => 7;

BEGIN {
    use_ok('KinoSearch::Analysis::LCNormalizer');
    use_ok('KinoSearch::Analysis::Tokenizer');
    use_ok('KinoSearch::Analysis::Stopalizer');
    use_ok('KinoSearch::Analysis::Stemmer');
    use_ok('KinoSearch::Analysis::PolyAnalyzer');
    use_ok('KinoSearch::Analysis::TokenBatch');
}

my $lc_normalizer = KinoSearch::Analysis::LCNormalizer->new;
my $tokenizer     = KinoSearch::Analysis::Tokenizer->new;
my $stopalizer    = KinoSearch::Analysis::Stopalizer->new( language => 'en' );
my $stemmer       = KinoSearch::Analysis::Stemmer->new( language => 'en' );
my $polyanalyzer  = KinoSearch::Analysis::PolyAnalyzer->new(
    analyzers => [ $lc_normalizer, $tokenizer, $stopalizer, $stemmer, ], );

my $batch = KinoSearch::Analysis::TokenBatch->new(
    text => 'Eats, shoots and leaves.', );
$batch = $polyanalyzer->analyze($batch);

my @got;
while ( my $token = $batch->next ) {
    push @got, $token->get_text;
}
is_deeply(
    \@got,
    [ 'eat', 'shoot', '', 'leav' ],
    'all aspects of polyanalyzer do their work'
);

