use strict;
use warnings;
use lib 'buildlib';

package main;
use Test::More tests => 9;

use KinoSearch::InvIndexer;
use KinoSearch::Searcher;
use KinoSearch::Index::Term;
use KinoSearch::Search::TermQuery;
use KinoSearch::Store::RAMFolder;
use KinoSearch::InvIndex;
use KinoSearch::Util::VArray;
use KinoSearch::Util::Int;

use KinoTestUtils qw( create_invindex );

my $invindex = create_invindex( ('common') x 10 );

my $term = KinoSearch::Index::Term->new( 'content', 'common' );
my $term_query = KinoSearch::Search::TermQuery->new( term => $term );
my $searcher   = KinoSearch::Searcher->new( invindex      => $invindex );
my $weight     = $searcher->create_weight($term_query);

my $got = test_search();
is_deeply( $got, [ 0 .. 9 ], "defaults" );

$got = test_search( start => 3 );
is_deeply( $got, [ 3 .. 9 ], "start" );

$got = test_search( end => 5 );
is_deeply( $got, [ 0 .. 4 ], "end" );

$got = test_search( prune_factor => 2 );
is_deeply( $got, [ 0 .. 1 ], "prune_factor without seg_starts" );

$got = test_search( prune_factor => 2, seg_starts => [ 0, 5 ] );
is_deeply( $got, [ 0, 1, 5, 6 ], "prune_factor" );

$got = test_search( prune_factor => 2, seg_starts => [ 1, 0, 5 ] );
is_deeply( $got, [ 1, 2, 5, 6 ], "malformed seg starts" );

$got = test_search( prune_factor => 2, seg_starts => [ 2, 10 ] );
is_deeply( $got, [ 2, 3 ], "out of bounds seg starts" );

$got = test_search( prune_factor => 5, seg_starts => [ 1, 2, 3 ] );
is_deeply( $got, [ 1 .. 7 ], "prune_factor bigger than seg size" );

$searcher->set_prune_factor(2);
my $hits = $searcher->search( query => $term_query );
is( $hits->total_hits, 2, "Searcher->set_prune_factor" );

sub test_search {
    my %args = ( %KinoSearch::Search::Scorer::score_batch_args, @_ );

    # lie about segment starts
    my $seg_starts = KinoSearch::Util::VArray->new( capacity => 10 );
    for my $start ( @{ $args{seg_starts} } ) {
        $seg_starts->push( KinoSearch::Util::Int->new($start) );
    }

    my $scorer = $weight->scorer( $searcher->{ix_reader} );
    my $collector = KinoSearch::Search::TopDocCollector->new( size => 100 );
    $scorer->score_batch(
        hit_collector => $collector,
        start         => $args{start},
        end           => $args{end},
        prune_factor  => $args{prune_factor},
        seg_starts    => $seg_starts,
    );
    my $score_docs = $collector->get_hit_queue()->score_docs;
    my @doc_ids = map { $_->get_id } @$score_docs;
    return \@doc_ids;
}