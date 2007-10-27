use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 6;

use KinoSearch::Analysis::Analyzer;
use KinoTestUtils qw( utf8_test_strings test_analyzer );

package TestAnalyzer;
use base qw( KinoSearch::Analysis::Analyzer );
sub analyze_batch { $_[1] }    # satisfy mandatory override

package main;
my $analyzer = TestAnalyzer->new;

my ( $smiley, $not_a_smiley, $frowny ) = utf8_test_strings();

my ($got) = $analyzer->analyze_raw($not_a_smiley);
is( $got, $frowny, "analyze_raw upgrades non-UTF-8 correctly" );

($got) = $analyzer->analyze_raw($smiley);
is( $got, $smiley, "analyze_raw handles UTF-8 correctly" );

test_analyzer( $analyzer, 'foo', ['foo'], "Analyzer (no-op)" );
