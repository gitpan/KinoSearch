use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 21;

use KinoSearch::Search::HitCollector;
use KinoSearch::Searcher;
use KinoSearch::Search::TermQuery;
use KinoSearch::Index::Term;
use KinoSearch::Search::QueryFilter;

use KinoTestUtils qw( create_invindex );

## set up main objects
my ( $filter_1, $filter_2 );
{
    my $invindex_1
        = create_invindex( 'a x', 'b x', 'c x', 'a y', 'b y', 'c y' );
    my $invindex_2
        = create_invindex( 'a w', 'b w', 'c w', 'a z', 'b z', 'c z' );

    my $searcher_1 = KinoSearch::Searcher->new( invindex => $invindex_1 );
    my $searcher_2 = KinoSearch::Searcher->new( invindex => $invindex_2 );

    my $reader_1 = $searcher_1->get_reader;
    my $reader_2 = $searcher_2->get_reader;

    my $only_a_query = KinoSearch::Search::TermQuery->new(
        term => KinoSearch::Index::Term->new( 'content', 'a' ) );
    $filter_1
        = KinoSearch::Search::QueryFilter->new( query => $only_a_query );
    $filter_2
        = KinoSearch::Search::QueryFilter->new( query => $only_a_query );

    ## test index 1, filter 1
    my $hits = $searcher_1->search( query => 'x y z', filter => $filter_1 );
    is( $hits->total_hits, 2, 'filtering a query works' );

    ## test index 2, filter 2
    $hits = $searcher_2->search( query => 'x y z', filter => $filter_2 );
    is( $hits->total_hits, 1, 'filtering a query works' );

    ## compare 1-1 to 2-2
    my $cached_bits_1 = $filter_1->bits($reader_1);
    my $cached_bits_2 = $filter_2->bits($reader_2);
    ok( !$cached_bits_1->equals($cached_bits_2),
        'cached bits are unique (1-1 != 2-2)'
    );

    ## test copy of index 1, filter 1
    $hits = $searcher_1->search( query => 'w y z', filter => $filter_1 );
    my $bits = $filter_1->bits($reader_1);
    is( $hits->total_hits, 1, 'filtering a query works' );
    ok( $cached_bits_1->equals($bits),
        'cached bits are cached (1-1 == 1-1)' );
    ok( !$cached_bits_2->equals($bits),
        'cached bits are unique (2-2 != 1-1)'
    );

    ## test index 1, filter 2
    $hits = $searcher_1->search( query => 'w y z', filter => $filter_2 );
    my $cached_bits_3 = $bits = $filter_2->bits($reader_1);
    is( $hits->total_hits, 1, 'filtering a query works' );
    ok( !$cached_bits_1->equals($bits),
        'cached bits are unique (1-1 != 1-2)'
    );
    ok( !$cached_bits_2->equals($bits),
        'cached bits are unique (2-2 != 1-2)'
    );

    ## test copy of index 2, filter 2
    $hits = $searcher_2->search( query => 'x y z', filter => $filter_2 );
    $bits = $filter_2->bits($reader_2);
    is( $hits->total_hits, 1, 'filtering a query works' );
    ok( !$cached_bits_1->equals($bits),
        'cached bits are unique (1-1 != 2-2)'
    );
    ok( $cached_bits_2->equals($bits),
        'cached bits are cached (2-2 != 2-2)' );
    ok( !$cached_bits_3->equals($bits),
        'cached bits are unique (1-2 != 2-2)'
    );

    ## test copy of index 1, filter 2
    $hits = $searcher_1->search( query => 'x y z', filter => $filter_2 );
    $bits = $filter_2->bits($reader_1);
    is( $hits->total_hits, 2, 'filtering a query works' );
    ok( !$cached_bits_1->equals($bits),
        'cached bits are unique (1-1 != 1-2)'
    );
    ok( !$cached_bits_2->equals($bits),
        'cached bits are unique (2-2 != 1-2)'
    );
    ok( $cached_bits_3->equals($bits),
        'cached bits are cached (1-2 != 1-2)' );

    is( cached_count($filter_1), 1, 'cache count check correct' );
    is( cached_count($filter_2), 2, 'cache count check correct' );
}

# readers should be automatically undef'd, refcnt == 0
is( cached_count($filter_1), 0, 'cache count check correct' );
is( cached_count($filter_2), 0, 'cache count check correct' );

# no API to return cached_bits directly, so we poke inside
sub cached_count {
    my ($filter) = @_;
    return scalar grep { defined $filter->{cached_bits}{$_}{reader} }
        keys %{ $filter->{cached_bits} };
}
