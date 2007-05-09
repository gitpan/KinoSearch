use strict;
use warnings;

use Test::More tests => 25;

use KinoSearch::Util::ByteBuf qw( bb_compare bb_less_than );

sub get_bb { KinoSearch::Util::ByteBuf->new(shift) }

is( bb_compare( get_bb("foo"), get_bb("foo") ), 0, "equal terms" );
is( bb_compare( get_bb(""),    get_bb("") ),    0, "equal empty strings" );
is( bb_compare( get_bb("\0"), get_bb("\0") ), 0, "equal strings with nulls" );

cmp_ok( bb_compare( get_bb("foo"), get_bb("food") ),
    '<', 0, "shorter word sorts first" );
cmp_ok( bb_compare( get_bb("food"), get_bb("foo") ),
    '>', 0, "longer word sorts last" );
cmp_ok( bb_compare( get_bb("foo"), get_bb("foo\0") ),
    '<', 0, "null contributes to length" );
cmp_ok( bb_compare( get_bb("foo\0a"), get_bb("foo\0b") ),
    '<', 0, "null doesn't interfere with comparison" );

ok( bb_less_than( get_bb("foo"), get_bb("food") ), "less than" );
ok( !bb_less_than( get_bb(""), get_bb("") ), "equal empty strings lt" );
ok( !bb_less_than( get_bb("foo"),  get_bb("foo") ), "equal not less than" );
ok( !bb_less_than( get_bb("food"), get_bb("foo") ), "greater not less than" );

ok( bb_less_than( get_bb("foo"),     get_bb("foo\0") ),  "lt with null" );
ok( !bb_less_than( get_bb("foo\0"),  get_bb("foo") ),    "gt with null" );
ok( bb_less_than( get_bb("foo\0a"),  get_bb("foo\0b") ), "lt with mid null" );
ok( !bb_less_than( get_bb("foo\0b"), get_bb("foo\0a") ), "gt with mid null" );

my $bb = get_bb("foo\0ab");
ok( $bb->starts_with( get_bb("fo") ),     "starts with" );
ok( !$bb->starts_with( get_bb("fo\0") ),  "starts with not fooled by null" );
ok( $bb->starts_with( get_bb("foo\0a") ), "starts with including null" );
ok( !$bb->starts_with( get_bb("foo\0x") ),
    "starts with not fooled after null"
);
ok( $bb->starts_with($bb), "starts with self" );
ok( !$bb->starts_with( get_bb("foo\0ab\0") ), "extra length fails" );

ok( $bb->ends_with( get_bb("ab") ),      "ends with" );
ok( $bb->ends_with( get_bb("\0ab") ),    "ends with not fooled by null" );
ok( !$bb->ends_with( get_bb("\0ab\0") ), "extra trailing null fails" );
ok( $bb->ends_with( get_bb("o\0ab") ),   "ends with including null" );
