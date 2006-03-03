use strict;
use warnings;

use Test::More tests => 3;

BEGIN { use_ok('KinoSearch::Search::HitCollector') }

my @docs_and_scores = ( [ 0, 2 ], [ 5, 0 ], [ 10, 0 ], [ 1000, 1 ] );

my $hc = KinoSearch::Search::HitQueueCollector->new( size => 3, );

$hc->collect( $_->[0], $_->[1] ) for @docs_and_scores;

my $hit_queue = $hc->get_storage;
isa_ok( $hit_queue, 'KinoSearch::Search::HitQueue' );

my $hit_docs = $hit_queue->hit_docs;

my @scores = map { $_->get_score } @$hit_docs;
is_deeply( \@scores, [ 2, 1, 0 ], "collect into HitQueue" );

