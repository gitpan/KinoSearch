use strict;
use warnings;

use Test::More tests => 2;

use KinoSearch::Search::HitQueue;
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
        score   => $_->[0],
        doc_num => $_->[1],
        )
} @docs_and_scores;

my @correct_order = sort {
           $b->get_score <=> $a->get_score
        or $a->get_doc_num <=> $b->get_doc_num
} @score_docs;
my @correct_docs   = map { $_->get_doc_num } @correct_order;
my @correct_scores = map { $_->get_score } @correct_order;

$hq->insert($_) for @score_docs;
my $got = $hq->score_docs;

my @scores = map { $_->get_score } @$got;
is_deeply( \@scores, \@correct_scores, "rank by scores first" );

my @doc_nums = map { $_->get_doc_num } @$got;
is_deeply( \@doc_nums, \@correct_docs, "rank by doc_num after score" );
