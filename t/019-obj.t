use strict;
use warnings;

use Test::More tests => 16;

use KinoSearch::Util::Obj;

my $object = KinoSearch::Util::Obj->_new;
isa_ok( $object, "KinoSearch::Util::Obj" );

is( $object->refcount, 1, "Correct starting refcount" );

$object->refcount_inc;
is( $object->refcount, 2, "refcount_inc" );

$object->refcount_dec;
is( $object->refcount, 1, "refcount_dec" );

like(
    $object->to_string,
    qr/KinoSearch::Util::Obj\@0x\w+/,
    "default to_string"
);

eval { my $evil_twin = $object->clone };
like( $@, qr/abstract/i, "clone throws an abstract method exception" );

my $other = KinoSearch::Util::Obj->_new;
ok( $object->equals($object), "equals is true for the same object" );
ok( !$object->equals($other), "Distinct objects are not equal" );

my $hash_code = sprintf( "%x", $object->hash_code );
like( $object->to_string, qr/$hash_code/, "hash code uses memory address" );

ok( $object->is_a("KinoSearch::Util::Obj"),     "custom is_a correct" );
ok( !$object->is_a("KinoSearch::Util::Object"), "custom is_a too long" );
ok( !$object->is_a("KinoSearch::Util"),         "custom is_a substring" );
ok( !$object->is_a(""),                         "custom is_a blank" );
ok( !$object->is_a("thing"),                    "custom is_a wrong" );

require KinoSearch::Util::ByteBuf;
my $bytebuf = KinoSearch::Util::ByteBuf->new("stuff");
ok( $bytebuf->is_a("KinoSearch::Util::ByteBuf"), "bytebuf is_a ByteBuf" );
ok( $bytebuf->is_a("KinoSearch::Util::Obj"),     "bytebuf is_a Obj" );
