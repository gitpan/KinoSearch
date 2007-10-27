use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 9;
use Carp;

use KinoSearch::Searcher;

use KinoTestUtils qw( persistent_test_invindex_loc );
use USConSchema;

my $searcher = KinoSearch::Searcher->new(
    invindex => USConSchema->read( persistent_test_invindex_loc() ), );
isa_ok( $searcher, 'KinoSearch::Searcher' );

my %searches = (
    'United'              => 34,
    'shall'               => 50,
    'not'                 => 27,
    '"shall not"'         => 21,
    'shall not'           => 51,
    'Congress'            => 31,
    'Congress AND United' => 22,
    '(Congress AND United) OR ((Vice AND President) OR "free exercise")' =>
        28,
);

while ( my ( $qstring, $num_expected ) = each %searches ) {
    my $hits = $searcher->search( query => $qstring );
    is( $hits->total_hits, $num_expected, $qstring );
}

