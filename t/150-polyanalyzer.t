use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 20;

use KinoTestUtils qw( test_analyzer );

use KinoSearch::Analysis::LCNormalizer;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Analysis::Stopalizer;
use KinoSearch::Analysis::Stemmer;
use KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::Analysis::TokenBatch;

my $source_text = 'Eats, shoots and leaves.';

my $lc_normalizer = KinoSearch::Analysis::LCNormalizer->new;
my $tokenizer     = KinoSearch::Analysis::Tokenizer->new;
my $stopalizer    = KinoSearch::Analysis::Stopalizer->new( language => 'en' );
my $stemmer       = KinoSearch::Analysis::Stemmer->new( language => 'en' );

my $polyanalyzer
    = KinoSearch::Analysis::PolyAnalyzer->new( analyzers => [], );
test_analyzer( $polyanalyzer, $source_text, [$source_text],
    'no sub analyzers' );

$polyanalyzer
    = KinoSearch::Analysis::PolyAnalyzer->new( analyzers => [$lc_normalizer],
    );
test_analyzer(
    $polyanalyzer, $source_text,
    ['eats, shoots and leaves.'],
    'with LCNormalizer'
);

$polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
    analyzers => [ $lc_normalizer, $tokenizer ], );
test_analyzer(
    $polyanalyzer, $source_text,
    [ 'eats', 'shoots', 'and', 'leaves' ],
    'with Tokenizer'
);

$polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
    analyzers => [ $lc_normalizer, $tokenizer, $stopalizer ], );
test_analyzer(
    $polyanalyzer, $source_text,
    [ 'eats', 'shoots', 'leaves' ],
    'with Stopalizer'
);

$polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
    analyzers => [ $lc_normalizer, $tokenizer, $stopalizer, $stemmer, ], );
test_analyzer( $polyanalyzer, $source_text, [ 'eat', 'shoot', 'leav' ],
    'with Stemmer' );

