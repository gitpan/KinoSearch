use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 2;

use KinoSearch::Search::HitCollector;
use KinoSearch::Searcher;
use KinoSearch::Search::TermQuery;
use KinoSearch::Index::Term;

BEGIN { use_ok('KinoSearch::Search::QueryFilter') }

use KinoTestUtils qw( create_invindex );

my $invindex = create_invindex( 'a x', 'b x', 'c x', 'a y', 'b y', 'c y' );

my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );

my $only_a_query = KinoSearch::Search::TermQuery->new(
    term => KinoSearch::Index::Term->new( 'content', 'a' ), );
my $filter = KinoSearch::Search::QueryFilter->new( query => $only_a_query, );

my $hits = $searcher->search(
    query  => 'x y',
    filter => $filter,
);
$hits->seek( 0, 50 );

is( $hits->total_hits, 2, "filtering a query works" );

