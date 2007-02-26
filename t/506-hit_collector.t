use strict;
use warnings;

use Test::More tests => 6;

BEGIN { use_ok('KinoSearch::Search::HitCollector') }
BEGIN { use_ok('KinoSearch::Search::TopDocCollector') }

use KinoSearch::Util::BitVector;

my @docs_and_scores = ( [ 0, 2 ], [ 5, 0 ], [ 10, 0 ], [ 1000, 1 ] );

my $hc = KinoSearch::Search::TopDocCollector->new( size => 3, );
$hc->collect( $_->[0], $_->[1] ) for @docs_and_scores;

my $hit_queue = $hc->get_hit_queue;
isa_ok( $hit_queue, 'KinoSearch::Search::HitQueue' );

my @scores = map { $_->get_score } @{ $hit_queue->score_docs };
is_deeply( \@scores, [ 2, 1, 0 ], "collect into HitQueue" );

my $bit_vec = KinoSearch::Util::BitVector->new;
$hc = KinoSearch::Search::HitCollector->new_bit_coll(
    bit_vector => $bit_vec );
$hc->collect( $_->[0], $_->[1] ) for @docs_and_scores;
is_deeply(
    $bit_vec->to_arrayref,
    [ 0, 5, 10, 1000 ],
    "BitCollector collects the right doc nums"
);

$bit_vec = KinoSearch::Util::BitVector->new;
my $inner_coll = KinoSearch::Search::HitCollector->new_bit_coll(
    bit_vector => $bit_vec );
my $offset_coll = KinoSearch::Search::HitCollector->new_offset_coll(
    hit_collector => $inner_coll,
    offset        => 10,
);
$offset_coll->collect( $_->[0], $_->[1] ) for @docs_and_scores;
is_deeply( $bit_vec->to_arrayref, [ 10, 15, 20, 1010 ], "Offset collector" );

