use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 3;

BEGIN { use_ok('KinoSearch::Analysis::Analyzer'); }

use KinoTestUtils qw( utf8_test_strings );

my $analyzer = KinoSearch::Analysis::Analyzer->new;

my ( $smiley, $not_a_smiley, $frowny ) = utf8_test_strings();

my ($got) = $analyzer->analyze_raw($not_a_smiley);
is( $got, $frowny, "analyze_raw upgrades non-UTF-8 correctly" );

($got) = $analyzer->analyze_raw($smiley);
is( $got, $smiley, "analyze_raw handles UTF-8 correctly" );
