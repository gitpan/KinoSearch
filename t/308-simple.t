use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 7;
use KinoSearch::Simple;
use KinoTestUtils qw( init_test_invindex_loc );

my $test_invindex_loc = init_test_invindex_loc();

my $index = KinoSearch::Simple->new(
    language => 'en',
    path     => $test_invindex_loc,
);

$index->add_doc( { food => 'creamed corn' } );
is( $index->search( query => 'creamed' ), 1, "search warks right after add" );

$index->add_doc( { food => 'creamed spinach' } );
is( $index->search( query => 'creamed' ), 2, "search returns total hits" );

$index->add_doc( { food => 'creamed broccoli' } );
undef $index;
$index = KinoSearch::Simple->new(
    language => 'en',
    path     => $test_invindex_loc,
);
is( $index->search( query => 'cream' ), 3, "commit upon destroy" );

while ( my $hit = $index->fetch_hit_hashref ) {
    like( $hit->{food}, qr/cream/, 'fetch_hit_hashref' );
}

$index->add_doc( { band => 'Cream' } );
is( $index->search( query => 'cream' ),
    4, "search uses correct PolyAnalyzer" );

