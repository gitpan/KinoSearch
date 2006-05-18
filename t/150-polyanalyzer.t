#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 7;
use bytes;

BEGIN {
    use_ok('KinoSearch::Analysis::LCNormalizer');
    use_ok('KinoSearch::Analysis::Tokenizer');
    use_ok('KinoSearch::Analysis::Stopalizer');
    use_ok('KinoSearch::Analysis::Stemmer');
    use_ok('KinoSearch::Analysis::PolyAnalyzer');
    use_ok('KinoSearch::Analysis::TokenBatch');
}

my $batch = KinoSearch::Analysis::TokenBatch->new;

my $lc_normalizer = KinoSearch::Analysis::LCNormalizer->new;
my $tokenizer     = KinoSearch::Analysis::Tokenizer->new;
my $stopalizer    = KinoSearch::Analysis::Stopalizer->new( language => 'en' );
my $stemmer       = KinoSearch::Analysis::Stemmer->new( language => 'en' );
my $polyanalyzer  = KinoSearch::Analysis::PolyAnalyzer->new(
    analyzers => [ $lc_normalizer, $tokenizer, $stopalizer, $stemmer, ], );

my $input = 'Eats, shoots and leaves.';
$batch->add_token( $input, 0, bytes::length($input) );
$batch = $polyanalyzer->analyze($batch);

my @got;
while ( $batch->next ) {
    push @got, $batch->get_text;
}
is_deeply(
    \@got,
    [ 'eat', 'shoot', '', 'leav' ],
    'all aspects of polyanalyzer do their work'
);

