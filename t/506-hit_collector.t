use strict;
use warnings;

use Test::More tests => 6;

package EvensOnlyHitCollector;
use base qw( KinoSearch::Search::HitCollector );

our %doc_ids;

sub new {
    my $self = shift->SUPER::new;
    $doc_ids{$$self} = [];
    return $self;
}

sub collect {
    my ( $self, $doc_id ) = @_;
    if ( $doc_id % 2 == 0 ) {
        push @{ $doc_ids{$$self} }, $doc_id;
    }
}

sub get_doc_ids { $doc_ids{ ${ +shift } } }

sub DESTROY {
    my $self = shift;
    delete $doc_ids{$$self};
    $self->SUPER::DESTROY;
}

package main;

use KinoSearch::Test;
use KSx::Search::MockScorer;

my @docs   = ( 1, 5, 10, 1000 );
my @scores = ( 2, 0, 0,  1 );

my $hc = KinoSearch::Search::HitCollector::SortCollector->new( wanted => 3 );
test_collect($hc);

my @got = map { $_->get_score } @{ $hc->pop_match_docs };
is_deeply( \@got, [ 2, 1, 0 ], "collect into HitQueue" );

$hc = KinoSearch::Search::HitCollector::SortCollector->new( wanted => 0 );
test_collect($hc);
is( $hc->get_total_hits, 4,
    "get_total_hits is accurate when no hits are requested" );
my $match_docs = $hc->pop_match_docs;
is( scalar @$match_docs, 0, "no hits wanted, so no hits returned" );

my $bit_vec = KinoSearch::Obj::BitVector->new;
$hc = KinoSearch::Search::HitCollector::BitCollector->new(
    bit_vector => $bit_vec );
test_collect($hc);
is_deeply(
    $bit_vec->to_arrayref,
    [ 1, 5, 10, 1000 ],
    "BitCollector collects the right doc nums"
);

$bit_vec = KinoSearch::Obj::BitVector->new;
my $inner_coll = KinoSearch::Search::HitCollector::BitCollector->new(
    bit_vector => $bit_vec );
my $offset_coll = KinoSearch::Search::HitCollector::OffsetCollector->new(
    collector => $inner_coll,
    offset    => 10,
);
test_collect($offset_coll);
is_deeply( $bit_vec->to_arrayref, [ 11, 15, 20, 1010 ], "Offset collector" );

$hc = EvensOnlyHitCollector->new;
test_collect($hc);
is_deeply( $hc->get_doc_ids, [ 10, 1000 ], "HitCollector can be subclassed" );

sub test_collect {
    my $hc      = shift;
    my $matcher = KSx::Search::MockScorer->new(
        doc_ids => \@docs,
        scores  => \@scores,
    );
    $hc->set_matcher($matcher);
    while ( my $doc_id = $matcher->next ) {
        $hc->collect($doc_id);
    }
}
