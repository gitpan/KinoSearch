use strict;
use warnings;

use Test::More tests => 343;
use List::Util qw( shuffle );

use KinoSearch::Util::BitVector;

my $bit_vec = KinoSearch::Util::BitVector->new( capacity => 9 );
$bit_vec->set(2);
my @got = map { $bit_vec->get($_) } 0 .. 9;
is_deeply(
    \@got,
    [ 0, 0, 1, 0, 0, 0, 0, 0, 0, 0 ],
    "set and get, including out-of-range get"
);

$bit_vec = KinoSearch::Util::BitVector->new( capacity => 1 );
my $old_cap = $bit_vec->get_cap;
$bit_vec->set(9);

cmp_ok( $bit_vec->get_cap, '>', $old_cap,
    "capacity should grow with above-range set" );
is( $bit_vec->get_bits, "\x00\x02", "bits have grown with above-range set" );

$bit_vec = KinoSearch::Util::BitVector->new;
$bit_vec->flip($_) for 0 .. 20;
is_deeply( $bit_vec->to_arrayref, [ 0 .. 20 ], "flip on" );
$bit_vec->flip($_) for 0 .. 20;
is_deeply( $bit_vec->to_arrayref, [], "flip off" );

$bit_vec = KinoSearch::Util::BitVector->new;
for ( 0 .. 20 ) {
    $bit_vec->flip_range( $_, 21 );
}
is_deeply(
    $bit_vec->to_arrayref,
    [ 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20 ],
    'flip range ascending'
);

$bit_vec = KinoSearch::Util::BitVector->new;
for ( reverse 1 .. 20 ) {
    $bit_vec->flip_range( 1, $_ );
}
is_deeply(
    $bit_vec->to_arrayref,
    [ 1, 3, 5, 7, 9, 11, 13, 15, 17, 19 ],
    'flip range descending'
);

for my $lower ( 0 .. 17 ) {
    for my $amount ( 0 .. 17 ) {
        my $upper = $lower + $amount;
        $bit_vec = KinoSearch::Util::BitVector->new;
        $bit_vec->flip_range( $lower, $upper );
        my $expected = $lower == $upper ? [] : [ $lower .. $upper - 1 ];
        is_deeply( $bit_vec->to_arrayref, $expected,
            "flip range $lower .. $upper" );
    }
}

my @set_1 = ( 1 .. 3,  10, 20, 30 );
my @set_2 = ( 2 .. 10, 25 .. 35 );

$bit_vec = KinoSearch::Util::BitVector->new;
my $other = KinoSearch::Util::BitVector->new;
$bit_vec->set(@set_1);
$other->set(@set_2);
$bit_vec->OR($other);
is_deeply(
    $bit_vec->to_arrayref,
    [ 1 .. 10, 20, 25 .. 35 ],
    "OR with self smaller than other"
);

$bit_vec = KinoSearch::Util::BitVector->new;
$other   = KinoSearch::Util::BitVector->new;
$bit_vec->set(@set_2);
$other->set(@set_1);
$bit_vec->OR($other);
is_deeply(
    $bit_vec->to_arrayref,
    [ 1 .. 10, 20, 25 .. 35 ],
    "OR with other smaller than self"
);

$bit_vec = KinoSearch::Util::BitVector->new;
$other   = KinoSearch::Util::BitVector->new;
$bit_vec->set(@set_1);
$other->set(@set_2);
$bit_vec->XOR($other);
is_deeply(
    $bit_vec->to_arrayref,
    [ 1, 4 .. 9, 20, 25 .. 29, 31 .. 35 ],
    "XOR with self smaller than other"
);

$bit_vec = KinoSearch::Util::BitVector->new;
$other   = KinoSearch::Util::BitVector->new;
$bit_vec->set(@set_2);
$other->set(@set_1);
$bit_vec->XOR($other);
is_deeply(
    $bit_vec->to_arrayref,
    [ 1, 4 .. 9, 20, 25 .. 29, 31 .. 35 ],
    "XOR with other smaller than self"
);

$bit_vec = KinoSearch::Util::BitVector->new;
$other   = KinoSearch::Util::BitVector->new;
$bit_vec->set(@set_1);
$other->set(@set_2);
$bit_vec->AND_NOT($other);
is_deeply(
    $bit_vec->to_arrayref,
    [ 1, 20 ],
    "AND_NOT with self smaller than other"
);

$bit_vec = KinoSearch::Util::BitVector->new;
$other   = KinoSearch::Util::BitVector->new;
$bit_vec->set(@set_2);
$other->set(@set_1);
$bit_vec->AND_NOT($other);
is_deeply(
    $bit_vec->to_arrayref,
    [ 4 .. 9, 25 .. 29, 31 .. 35 ],
    "AND_NOT with other smaller than self"
);

$bit_vec = KinoSearch::Util::BitVector->new;
$other   = KinoSearch::Util::BitVector->new;
$bit_vec->set(@set_1);
$other->set(@set_2);
$bit_vec->AND($other);
is_deeply(
    $bit_vec->to_arrayref,
    [ 2, 3, 10, 30 ],
    "AND with self smaller than other"
);

$bit_vec = KinoSearch::Util::BitVector->new;
$other   = KinoSearch::Util::BitVector->new;
$bit_vec->set(@set_2);
$other->set(@set_1);
$bit_vec->AND($other);
is_deeply(
    $bit_vec->to_arrayref,
    [ 2, 3, 10, 30 ],
    "AND with other smaller than self"
);

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
