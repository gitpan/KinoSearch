#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 3;

BEGIN { use_ok('KinoSearch::Analysis::LCNormalizer') }
use KinoSearch::Analysis::TokenBatch;

my $lc_normalizer = KinoSearch::Analysis::LCNormalizer->new;

my $batch = KinoSearch::Analysis::TokenBatch->new;
$batch->append( "caPiTal ofFensE", 0, 15 );
$batch = $lc_normalizer->analyze($batch);
$batch->next;
is( $batch->get_text, "capital offense", "lc plain text" );

$batch = KinoSearch::Analysis::TokenBatch->new;
$batch->append( $_, 10, 20 ) for qw( eL sEE );
$batch = $lc_normalizer->analyze($batch);

my @texts;
while ( $batch->next ) {
    push @texts, $batch->get_text;
}
is_deeply( \@texts, [qw( el see )], "analyze an existing batch" );

