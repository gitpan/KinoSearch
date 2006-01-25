use strict;
use warnings;

use Test::More tests => 3;
use Scalar::Util qw( dualvar );

BEGIN { use_ok('KinoSearch::Search::HitQueue') }

my $hq = KinoSearch::Search::HitQueue->new( max_size => 3 );

my @docs_and_scores = ( [ 1.0, 0 ], [ 0.1, 5 ], [ 0.1, 10 ], [ 0.9, 1000 ] );
my @scoredocs
    = map { dualvar( $_->[0], pack( 'N', $_->[1] ) ) } @docs_and_scores;

my $hit_docs;
$hq->insert($_) for @scoredocs;
$hit_docs = $hq->hit_docs;

my @scores = map { $_->get_score } @$hit_docs;
is_deeply( \@scores, [ 1, 0.9, 0.1 ], "collect the three high scores" );

is( $hit_docs->[2]->get_doc_num, 5, "rank by doc_num after score" );

