use strict;
use warnings;

use Test::More tests => 3;

BEGIN { use_ok('KinoSearch::Analysis::LCNormalizer') }

use KinoSearch::Analysis::Token;
use KinoSearch::Analysis::TokenBatch;

my $lc_normalizer = KinoSearch::Analysis::LCNormalizer->new;

my $batch
    = KinoSearch::Analysis::TokenBatch->new( text => "caPiTal ofFensE" );
$batch = $lc_normalizer->analyze($batch);
is( $batch->next->get_text, "capital offense", "lc plain text" );

$batch = KinoSearch::Analysis::TokenBatch->new;
for (qw( eL sEE )) {
    my $token = KinoSearch::Analysis::Token->new(
        text         => $_,
        start_offset => 10,
        end_offset   => 20
    );
    $batch->append($token);
}
$batch = $lc_normalizer->analyze($batch);

my @texts;
while ( my $token = $batch->next ) {
    push @texts, $token->get_text;
}
is_deeply( \@texts, [qw( el see )], "analyze an existing batch" );

