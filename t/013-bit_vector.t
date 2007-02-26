use strict;
use warnings;

use Test::More tests => 9;
use List::Util qw( shuffle );

BEGIN { use_ok('KinoSearch::Util::BitVector') }

my $bit_vec = KinoSearch::Util::BitVector->new( capacity => 9 );

$bit_vec->set(2);
my @got = map { $bit_vec->get($_) } 0 .. 9;
is_deeply(
    \@got,
    [ 0, 0, 1, 0, 0, 0, 0, 0, 0, 0 ],
    "set and get, including out-of-range get"
);

$bit_vec = KinoSearch::Util::BitVector->new( capacity => 25 );

$bit_vec = KinoSearch::Util::BitVector->new;
$bit_vec->set(9);

is( $bit_vec->get_capacity, 10, "capacity should grow with above-range set" );
is( $bit_vec->get_bits, "\x00\x02", "bits have grown with above-range set" );

$bit_vec = KinoSearch::Util::BitVector->new;
my $other = KinoSearch::Util::BitVector->new;
$bit_vec->set( 1 .. 3, 10, 20, 30 );
$other->set( 2 .. 10, 25 .. 35 );
$bit_vec->logical_and($other);
is_deeply( $bit_vec->to_arrayref, [ 2, 3, 10, 30 ], "logical_and" );

my $evil_twin = $bit_vec->clone;
is_deeply( $evil_twin->to_arrayref, [ 2, 3, 10, 30 ], "clone" );
is( $evil_twin->count, 4, "clone count" );
is( $bit_vec->get_bits, $evil_twin->get_bits, "cloned bits" );

$bit_vec = KinoSearch::Util::BitVector->new;
my @counts;
for ( shuffle 1 .. 64 ) {
    $bit_vec->set($_);
    push @counts, $bit_vec->count;
}
is_deeply( \@counts, [ 1 .. 64 ],
    'count() returns the right number of bits' );

# valgrind only - detect off-by-one error
for my $cap ( 5 .. 24 ) {
    $bit_vec = KinoSearch::Util::BitVector->new( capacity => $cap );
    $bit_vec->set( $cap - 2 );
}

