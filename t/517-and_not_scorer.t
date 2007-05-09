use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 4;

use KinoSearch::Search::ANDNOTScorer;
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
my $reader     = $searcher->get_reader;
my $similarity = KinoSearch::Search::Similarity->new;

my $c_query = KinoSearch::Search::TermQuery->new(
    term => KinoSearch::Index::Term->new( 'content', 'c' ) );
my $c_weight = $searcher->create_weight($c_query);
my $x_query  = KinoSearch::Search::TermQuery->new(
    term => KinoSearch::Index::Term->new( 'content', 'x' ) );
my $x_weight = $searcher->create_weight($x_query);

my $and_not_scorer = KinoSearch::Search::ANDNOTScorer->new(
    similarity => $similarity,
    and_scorer => $c_weight->scorer($reader),
    not_scorer => $x_weight->scorer($reader),
);
my $collector = KinoSearch::Search::TopDocCollector->new( size => 10 );
$and_not_scorer->collect( collector => $collector );
is( $collector->get_total_hits, 3, "not_scorer more common (hits)" );
is_deeply(
    dig_out_doc_nums($collector),
    [ 2, 8, 9 ],
    "not_scorer more commont (doc_nums)"
);

$and_not_scorer = KinoSearch::Search::ANDNOTScorer->new(
    similarity => $similarity,
    and_scorer => $x_weight->scorer($reader),
    not_scorer => $c_weight->scorer($reader),
);
$collector = KinoSearch::Search::TopDocCollector->new( size => 100 );
$and_not_scorer->collect( collector => $collector );
is( $collector->get_total_hits, 90, "not_scorer more common (hits)" );
is_deeply(
    dig_out_doc_nums($collector),
    [ 11 .. 100 ],
    "not_scorer more commont (doc_nums)"
);

sub dig_out_doc_nums {
    my $hc = shift;
    my @doc_nums;
    my $score_docs = $hc->get_hit_queue->score_docs;
    for (@$score_docs) {
        push @doc_nums, $_->get_doc_num;
    }
    return \@doc_nums;
}

