use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 24;
use Storable qw( nfreeze thaw );
use KinoSearch::Test;
use KinoSearch::Test::TestUtils qw( create_index );
use KSx::Search::Filter;

my $query_parser = KinoSearch::Search::QueryParser->new(
    schema => KinoSearch::Test::TestSchema->new );

## Set up main objects.
my ( $filter_1, $filter_2 );
{
    my $folder_1 = create_index( 'a x', 'b x', 'c x', 'a y', 'b y', 'c y' );
    my $folder_2 = create_index( 'a w', 'b w', 'c w', 'a z', 'b z', 'c z' );

    my $searcher_1
        = KinoSearch::Search::IndexSearcher->new( index => $folder_1 );
    my $searcher_2
        = KinoSearch::Search::IndexSearcher->new( index => $folder_2 );

    my $reader_1 = $searcher_1->get_reader->get_seg_readers->[0];
    my $reader_2 = $searcher_2->get_reader->get_seg_readers->[0];

    my $only_a_query = KinoSearch::Search::TermQuery->new(
        field => 'content',
        term  => 'a',
    );
    $filter_1 = KSx::Search::Filter->new( query => $only_a_query );
    $filter_2 = KSx::Search::Filter->new( query => $only_a_query );

    ## Test index 1, filter 1.
    my $hits = $searcher_1->hits( query => filt_query( $filter_1, 'x y z' ) );
    is( $hits->total_hits, 2, 'filtering a query works' );

    ## Test index 2, filter 2.
    $hits = $searcher_2->hits( query => filt_query( $filter_2, 'x y z' ) );
    is( $hits->total_hits, 1, 'filtering a query works' );

    ## Compare 1-1 to 2-2.
    my $cached_bits_1 = $filter_1->_bits($reader_1);
    my $cached_bits_2 = $filter_2->_bits($reader_2);
    ok( !$cached_bits_1->equals($cached_bits_2),
        'cached bits are unique (1-1 != 2-2)'
    );

    ## Test copy of index 1, filter 1.
    $hits = $searcher_1->hits( query => filt_query( $filter_1, 'w y z' ) );
    my $bits = $filter_1->_bits($reader_1);
    is( $hits->total_hits, 1, 'filtering a query works' );
    ok( $cached_bits_1->equals($bits),
        'cached bits are cached (1-1 == 1-1)' );
    ok( !$cached_bits_2->equals($bits),
        'cached bits are unique (2-2 != 1-1)'
    );

    ## Test index 1, filter 2.
    $hits = $searcher_1->hits( query => filt_query( $filter_2, 'w y z' ) );
    my $cached_bits_3 = $bits = $filter_2->_bits($reader_1);
    is( $hits->total_hits, 1, 'filtering a query works' );
    ok( !$cached_bits_1->equals($bits),
        'cached bits are unique (1-1 != 1-2)'
    );
    ok( !$cached_bits_2->equals($bits),
        'cached bits are unique (2-2 != 1-2)'
    );

    ## Test copy of index 2, filter 2.
    $hits = $searcher_2->hits( query => filt_query( $filter_2, 'x y z' ) );
    $bits = $filter_2->_bits($reader_2);
    is( $hits->total_hits, 1, 'filtering a query works' );
    ok( !$cached_bits_1->equals($bits),
        'cached bits are unique (1-1 != 2-2)'
    );
    ok( $cached_bits_2->equals($bits),
        'cached bits are cached (2-2 != 2-2)' );
    ok( !$cached_bits_3->equals($bits),
        'cached bits are unique (1-2 != 2-2)'
    );

    ## Test copy of index 1, filter 2.
    $hits = $searcher_1->hits( query => filt_query( $filter_2, 'x y z' ) );
    $bits = $filter_2->_bits($reader_1);
    is( $hits->total_hits, 2, 'filtering a query works' );
    ok( !$cached_bits_1->equals($bits),
        'cached bits are unique (1-1 != 1-2)'
    );
    ok( !$cached_bits_2->equals($bits),
        'cached bits are unique (2-2 != 1-2)'
    );
    ok( $cached_bits_3->equals($bits),
        'cached bits are cached (1-2 != 1-2)' );

    is( $filter_1->_cached_count, 1, 'cache count check correct' );
    is( $filter_2->_cached_count, 2, 'cache count check correct' );
}

sub filt_query {
    my ( $filter, $query_string ) = @_;
    return KinoSearch::Search::ANDQuery->new(
        children => [ $filter, $query_parser->parse($query_string) ], );
}

# Readers should be automatically undef'd, refcnt == 0.
is( $filter_1->_cached_count, 0, 'cache count check correct' );
is( $filter_2->_cached_count, 0, 'cache count check correct' );

ok( $filter_1->equals($filter_2), 'equals' );
my $frozen = nfreeze($filter_1);
my $thawed = thaw($frozen);
ok( $thawed->equals($filter_1), 'freeze/thaw' );
is( $filter_1->to_string, "Filter(content:a)", "to_string" );
