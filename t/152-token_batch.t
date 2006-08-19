#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 2;

BEGIN { use_ok('KinoSearch::Analysis::TokenBatch') }
use KinoSearch::Analysis::Token;

my $batch = KinoSearch::Analysis::TokenBatch->new;
$batch->append( "car",   0,  3 );
$batch->append( "bike",  10, 14 );
$batch->append( "truck", 20, 25 );

my @texts;
while ( $batch->next ) {
    push @texts, $batch->get_text;
}
is_deeply( \@texts, [qw( car bike truck )], "return tokens in order" );

