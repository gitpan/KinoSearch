use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 8;
use KinoSearch::Test;
use KinoSearch::Test::TestUtils qw( create_index );

my $folder_a = create_index( 'x a', 'x b', 'x c' );
my $folder_b = create_index( 'y b', 'y c', 'y d' );
my $searcher_a = KinoSearch::Search::IndexSearcher->new( index => $folder_a );
my $searcher_b = KinoSearch::Search::IndexSearcher->new( index => $folder_b );

my $poly_searcher = KinoSearch::Search::PolySearcher->new(
    schema    => KinoSearch::Test::TestSchema->new,
    searchers => [ $searcher_a, $searcher_b ],
);

is( $poly_searcher->doc_freq( field => 'content', term => 'b' ),
    2, 'doc_freq' );
is( $poly_searcher->doc_max, 6, 'doc_max' );
is( $poly_searcher->fetch_doc( doc_id => 1 )->{content}, 'x a', "fetch_doc" );
isa_ok( $poly_searcher->fetch_doc_vec(1), 'KinoSearch::Index::DocVector' );

my $hits = $poly_searcher->hits( query => 'a' );
is( $hits->total_hits, 1, "Find hit in first searcher" );

$hits = $poly_searcher->hits( query => 'd' );
is( $hits->total_hits, 1, "Find hit in second searcher" );

$hits = $poly_searcher->hits( query => 'c' );
is( $hits->total_hits, 2, "Find hits in both searchers" );

my $bit_vec = KinoSearch::Object::BitVector->new(
    capacity => $poly_searcher->doc_max );
my $bitcoll = KinoSearch::Search::Collector::BitCollector->new(
    bit_vector => $bit_vec );
my $query = $poly_searcher->glean_query('b');
$poly_searcher->collect( query => $query, collector => $bitcoll );
is_deeply( $bit_vec->to_arrayref, [ 2, 4 ], "collect" );
