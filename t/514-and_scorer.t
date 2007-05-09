use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 8;

use KinoSearch::Search::ANDScorer;
use KinoSearch::Search::Similarity;
use KinoSearch::Search::TermQuery;
use KinoSearch::Search::TopDocCollector;
use KinoSearch::Search::Tally;
use KinoSearch::Index::Term;
use KinoSearch::Searcher;

use KinoTestUtils qw( create_invindex );

my @docs = ( 'a' .. 'h', 'c c', 'c d e', 'd e' );
push @docs, ('x') x 90;
push @docs, ('c d x');
my $invindex = create_invindex(@docs);

my $searcher   = KinoSearch::Searcher->new( invindex => $invindex, );
my $similarity = KinoSearch::Search::Similarity->new;

my $c_query = KinoSearch::Search::TermQuery->new(
    term => KinoSearch::Index::Term->new( 'content', 'c' ) );
my $c_weight = $searcher->create_weight($c_query);
my $d_query  = KinoSearch::Search::TermQuery->new(
    term => KinoSearch::Index::Term->new( 'content', 'd' ) );
my $d_weight = $searcher->create_weight($d_query);
my $e_query  = KinoSearch::Search::TermQuery->new(
    term => KinoSearch::Index::Term->new( 'content', 'e' ) );
my $e_weight = $searcher->create_weight($e_query);
my $x_query  = KinoSearch::Search::TermQuery->new(
    term => KinoSearch::Index::Term->new( 'content', 'x' ) );
my $x_weight = $searcher->create_weight($x_query);

my $conj_scorer
    = KinoSearch::Search::ANDScorer->new( similarity => $similarity );
$conj_scorer->add_subscorer( $c_weight->scorer( $searcher->get_reader ) );
my $collector = KinoSearch::Search::TopDocCollector->new( size => 10 );
$conj_scorer->collect( collector => $collector );
is( $collector->get_total_hits, 4, "single element" );
is_deeply(
    dig_out_doc_nums($collector),
    [ 2, 8, 9, 101 ],
    "single elem, correct doc nums"
);

$conj_scorer
    = KinoSearch::Search::ANDScorer->new( similarity => $similarity );
$conj_scorer->add_subscorer( $c_weight->scorer( $searcher->get_reader ) );
$conj_scorer->add_subscorer( $d_weight->scorer( $searcher->get_reader ) );
$collector = KinoSearch::Search::TopDocCollector->new( size => 10 );
$conj_scorer->collect( collector => $collector );
is( $collector->get_total_hits, 2, "two elements" );
is_deeply(
    dig_out_doc_nums($collector),
    [ 9, 101 ],
    "two elems, correct doc nums"
);

$conj_scorer
    = KinoSearch::Search::ANDScorer->new( similarity => $similarity );
$conj_scorer->add_subscorer( $c_weight->scorer( $searcher->get_reader ) );
$conj_scorer->add_subscorer( $d_weight->scorer( $searcher->get_reader ) );
$conj_scorer->add_subscorer( $e_weight->scorer( $searcher->get_reader ) );
$collector = KinoSearch::Search::TopDocCollector->new( size => 10 );
$conj_scorer->collect( collector => $collector );
is( $collector->get_total_hits, 1, "three elements" );
is_deeply( dig_out_doc_nums($collector),
    [9], "three elems, correct doc nums" );

$conj_scorer
    = KinoSearch::Search::ANDScorer->new( similarity => $similarity );
$conj_scorer->add_subscorer( $c_weight->scorer( $searcher->get_reader ) );
$conj_scorer->add_subscorer( $d_weight->scorer( $searcher->get_reader ) );
$conj_scorer->add_subscorer( $e_weight->scorer( $searcher->get_reader ) );
$conj_scorer->add_subscorer( $x_weight->scorer( $searcher->get_reader ) );
$collector = KinoSearch::Search::TopDocCollector->new( size => 10 );
$conj_scorer->collect( collector => $collector );
is( $collector->get_total_hits, 0, "four elems, but no match" );

$conj_scorer
    = KinoSearch::Search::ANDScorer->new( similarity => $similarity );
$collector = KinoSearch::Search::TopDocCollector->new( size => 10 );
$conj_scorer->collect( collector => $collector );
is( $collector->get_total_hits, 0, "no elems, no match" );

sub dig_out_doc_nums {
    my $hc = shift;
    my @doc_nums;
    my $score_docs = $hc->get_hit_queue->score_docs;
    for (@$score_docs) {
        push @doc_nums, $_->get_doc_num;
    }
    return \@doc_nums;
}

