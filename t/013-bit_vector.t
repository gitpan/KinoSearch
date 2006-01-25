use strict;
use warnings;

use Test::More tests => 13;

BEGIN { use_ok('KinoSearch::Util::BitVector') }

my @got;

my $bit_vec = KinoSearch::Util::BitVector->new( capacity => 9 );

$bit_vec->set(2);
@got = map { $bit_vec->get($_) } 0 .. 9;
is_deeply(
    \@got,
    [ '', '', 1, '', '', '', '', '', '', '' ],
    "set and get, including out-of-range get"
);

$bit_vec = KinoSearch::Util::BitVector->new( capacity => 9 );

$bit_vec->set(5);
is( $bit_vec->next_set_bit(5),   5, 'next_set_bit' );
is( $bit_vec->next_clear_bit(5), 6, 'next_clear_bit' );
is( $bit_vec->next_set_bit(6), undef,
          "next_set_bit should return undef when "
        . "the there's no set bit between the val and the end" );
$bit_vec->set(6);
$bit_vec->set(7);
$bit_vec->set(8);
is( $bit_vec->next_clear_bit(5),
    9, "... in same situation, clear returns the first out of range" );

$bit_vec = KinoSearch::Util::BitVector->new( capacity => 25 );

$bit_vec->bulk_set( 1, 22 );
@got = map { $bit_vec->get($_) } 0 .. 24;
my @wanted = ( '', (1) x 22, '', '' );

is_deeply( \@got, \@wanted, "bulk set" );

$bit_vec->bulk_clear( 2, 21 );
@got = map { $bit_vec->get($_) } 0 .. 24;
@wanted = ( '', 1, ('') x 20, 1, '', '' );
is_deeply( \@got, \@wanted, "bulk clear" );

$bit_vec = KinoSearch::Util::BitVector->new;
is( $bit_vec->get_capacity, 0, "default capacity of 0" );

$bit_vec->set_bits("\x02");
is( $bit_vec->get_capacity, 8, "set_bits has side effect of new capacity" );

@got = map { $bit_vec->get($_) } 0 .. 7;
is_deeply(
    \@got,
    [ '', 1, '', '', '', '', '', '' ],
    "set_bits was successful"
);

$bit_vec->set(9);
@got = map { $bit_vec->get($_) } 0 .. 15;

is( $bit_vec->get_capacity, 10, "capacity should grow with above-range set" );
is( $bit_vec->get_bits, "\x02\x02", "bits have grown with above-range set" );

# valgrind only - detect off-by-one error
for my $cap ( 5 .. 24 ) {
    $bit_vec = KinoSearch::Util::BitVector->new( capacity => $cap );
    $bit_vec->set( $cap - 2 );
    for ( 0 .. $cap ) {
        $bit_vec->next_set_bit($_);
    }
}
