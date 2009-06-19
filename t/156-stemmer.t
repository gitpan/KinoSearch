use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 6;
use KinoSearch::Test::TestUtils qw( test_analyzer );

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
