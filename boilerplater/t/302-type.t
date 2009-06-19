use strict;
use warnings;

use Test::More tests => 9;

BEGIN { use_ok('Boilerplater::Type') }
use Boilerplater::Parcel;

Boilerplater::Parcel->singleton( name => 'Boil' );
my %args = ( specifier => 'Obj', parcel => 'Boil' );

my $type = Boilerplater::Type->new(%args);
isa_ok( $type, "Boilerplater::Type" );
is( $type->get_specifier, 'boil_Obj', "add prefix to Object type name" );

eval { my $death = Boilerplater::Type->new( %args, extra => undef ) };
like( $@, qr/extra/, "Extra arg kills constructor" );

$type = Boilerplater::Type->new(
    specifier   => 'char',
    indirection => 1,
    const       => 1
);
ok( $type->const, "const" );
is( $type->to_c, "const char*", "to_c" );

$type = Boilerplater::Type->new(
    specifier   => 'u32_t',
    indirection => 2
);
like( $type->to_c, qr/chy_u32_t/,     "add chy_ prefix" );
like( $type->to_c, qr/chy_u32_t\*\*/, "normalize pointers" );

$type = Boilerplater::Type->new( specifier => 'method_t', array => '[1]' );
is( $type->to_c, "method_t", "array postfix omitted for C" );

