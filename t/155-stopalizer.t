#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 2;

BEGIN { use_ok('KinoSearch::Analysis::Stopalizer') }
use KinoSearch::Analysis::TokenBatch;
use KinoSearch::Analysis::Tokenizer;

my $tokenizer = KinoSearch::Analysis::Tokenizer->new;

my $batch = KinoSearch::Analysis::TokenBatch->new;
$batch->append( "i am the walrus", 0, 5 );
$batch = $tokenizer->analyze($batch);

my $stopalizer = KinoSearch::Analysis::Stopalizer->new( language => 'en' );
$batch = $stopalizer->analyze($batch);

my @token_texts;
while ( $batch->next ) {
    push @token_texts, $batch->get_text;
}
is_deeply( \@token_texts, ['', '', '', 'walrus'], "stopwords stopalized" );
