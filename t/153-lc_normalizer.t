use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 4;
use KinoTestUtils qw( test_analyzer );

use KinoSearch::Analysis::LCNormalizer;
use KinoSearch::Analysis::Token;
use KinoSearch::Analysis::TokenBatch;

my $lc_normalizer = KinoSearch::Analysis::LCNormalizer->new;

test_analyzer(
    $lc_normalizer,      "caPiTal ofFensE",
    ['capital offense'], 'lc plain text'
);
