use strict;
use warnings;

use Test::More tests => 3;
use Scalar::Util qw( dualvar );

BEGIN { use_ok('KinoSearch::Search::HitQueue') }
use KinoSearch::Search::ScoreDoc;

my $hq = KinoSearch::Search::HitQueue->new( max_size => 10 );

my @docs_and_scores = (
    [ 1.0, 0 ],
    [ 0.1, 5 ],
    [ 0.1, 10 ],
    [ 0.9, 1000 ],
    [ 1.0, 3000 ],
    [ 1.0, 2000 ],
);

my @score_docs = map {
    KinoSearch::Search::ScoreDoc->new(
        score => $_->[0],
        id    => $_->[1],
        )
} @docs_and_scores;

my @correct_order
    = sort { $b->get_score <=> $a->get_score or $a->get_id <=> $b->get_id }
    @score_docs;
my @correct_docs   = map { $_->get_id } @correct_order;
my @correct_scores = map { $_->get_score } @correct_order;

$hq->insert($_) for @score_docs;
my $got = $hq->score_docs;

my @scores = map { $_->get_score } @$got;
is_deeply( \@scores, \@correct_scores, "rank by scores first" );

my @doc_nums = map { $_->get_id } @$got;
is_deeply( \@doc_nums, \@correct_docs, "rank by doc_num after score" );

