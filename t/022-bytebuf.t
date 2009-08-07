use strict;
use warnings;

use Test::More tests => 8;
use Storable qw( freeze thaw );

use KinoSearch::Obj::ByteBuf qw( bb_compare );

sub get_bb { KinoSearch::Obj::ByteBuf->new(shift) }

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

my $orig   = get_bb("foo");
my $frozen = freeze($orig);
my $thawed = thaw($frozen);
is( $thawed->to_perl, $orig->to_perl, "freeze/thaw" );

