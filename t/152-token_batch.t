use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 4;

BEGIN { use_ok('KinoSearch::Analysis::TokenBatch') }

use KinoSearch::Analysis::Token;
use KinoTestUtils qw( utf8_test_strings );

my $batch = KinoSearch::Analysis::TokenBatch->new;
$batch->append(
    KinoSearch::Analysis::Token->new(
        text         => "car",
        start_offset => 0,
        end_offset   => 3,
    ),
);
$batch->append(
    KinoSearch::Analysis::Token->new(
        text         => "bike",
        start_offset => 10,
        end_offset   => 14,
    ),
);
$batch->append(
    KinoSearch::Analysis::Token->new(
        text         => "truck",
        start_offset => 20,
        end_offset   => 25,
    ),
);

my @texts;
while ( my $token = $batch->next ) {
    push @texts, $token->get_text;
}
is_deeply( \@texts, [qw( car bike truck )], "return tokens in order" );

my ( $smiley, $not_a_smiley, $frowny ) = utf8_test_strings();

$batch = KinoSearch::Analysis::TokenBatch->new( text => $smiley );
is( $batch->next->get_text, $smiley,
    "TokenBatch->new handles UTF-8 correctly" );
$batch = KinoSearch::Analysis::TokenBatch->new( text => $not_a_smiley );
is( $batch->next->get_text, $frowny,
    "TokenBatch->new upgrades non-UTF-8 correctly" );
