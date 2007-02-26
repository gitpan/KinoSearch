use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 4;

BEGIN { use_ok('KinoSearch::Search::MultiSearcher') }

use KinoSearch::Searcher;
use KinoSearch::Analysis::Tokenizer;

use KinoTestUtils qw( create_invindex );
my $invindex_a = create_invindex( 'x a', 'x b', 'x c' );
my $invindex_b = create_invindex( 'y b', 'y c', 'y d' );

my $tokenizer = KinoSearch::Analysis::Tokenizer->new;

my $searcher_a = KinoSearch::Searcher->new( invindex => $invindex_a, );
my $searcher_b = KinoSearch::Searcher->new( invindex => $invindex_b, );

my $multi_searcher = KinoSearch::Search::MultiSearcher->new(
    searchables => [ $searcher_a, $searcher_b ], );

my $hits = $multi_searcher->search( query => 'a' );
is( $hits->total_hits, 1, "Find hit in first searcher" );

$hits = $multi_searcher->search( query => 'd' );
is( $hits->total_hits, 1, "Find hit in second searcher" );

$hits = $multi_searcher->search( query => 'c' );
is( $hits->total_hits, 2, "Find hits in both searchers" );

