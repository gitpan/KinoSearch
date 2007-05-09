use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 6;
use KinoTestUtils qw( test_analyzer );

use KinoSearch::Analysis::Stemmer;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Analysis::PolyAnalyzer;

my $stemmer = KinoSearch::Analysis::Stemmer->new( language => 'en' );
test_analyzer( $stemmer, 'peas', ['pea'], "single word stemmed" );

my $tokenizer    = KinoSearch::Analysis::Tokenizer->new;
my $polyanalyzer = KinoSearch::Analysis::PolyAnalyzer->new(
    analyzers => [ $tokenizer, $stemmer ], );
test_analyzer(
    $polyanalyzer,
    'peas porridge hot',
    [ 'pea', 'porridg', 'hot' ],
    "multiple words stemmed",
);
