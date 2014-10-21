use strict;
use warnings;

use Test::More tests => 8;
use KinoSearch::Test;
use KinoSearch qw( to_perl to_kino );

my $object = KinoSearch::Object::Host->new();
isa_ok( $object, "KinoSearch::Object::Host" );

is( $object->_callback,     undef, "void callback" );
is( $object->_callback_f64, 5,     "f64 callback" );
is( $object->_callback_i64, 5,     "integer callback" );

my $test_obj = $object->_callback_obj;
isa_ok( $test_obj, "KinoSearch::Object::ByteBuf" );

my %complex_data_structure = (
    a => [ 1, 2, 3, { ooga => 'booga' } ],
    b => { foo => 'foofoo', bar => 'barbar' },
);
my $kobj = to_kino( \%complex_data_structure );
isa_ok( $kobj, 'KinoSearch::Object::Obj' );
my $transformed = to_perl($kobj);
is_deeply( $transformed, \%complex_data_structure,
    "transform from Perl to Kino data structures and back" );

my $bread_and_butter = KinoSearch::Object::Hash->new;
$bread_and_butter->store( 'bread',
    KinoSearch::Object::ByteBuf->new('butter') );
my $salt_and_pepper = KinoSearch::Object::Hash->new;
$salt_and_pepper->store( 'salt', KinoSearch::Object::ByteBuf->new('pepper') );
$complex_data_structure{c} = $bread_and_butter;
$complex_data_structure{d} = $salt_and_pepper;
$transformed               = to_perl( to_kino( \%complex_data_structure ) );
$complex_data_structure{c} = { bread => 'butter' };
$complex_data_structure{d} = { salt => 'pepper' };
is_deeply( $transformed, \%complex_data_structure,
    "handle mixed data structure correctly" );
