use strict;
use warnings;

use Test::More tests => 8;

use KinoSearch::Util::Native qw( to_perl to_kino );
use KinoSearch::Util::Hash;
use KinoSearch::Util::ByteBuf;

my $foo    = KinoSearch::Util::Native::Test->_new;
my $object = KinoSearch::Util::Native->new($foo);
isa_ok( $object, "KinoSearch::Util::Native" );

is( $object->_callback,    undef, "void callback" );
is( $object->_callback_f,  4,     "float callback" );
is( $object->_callback_i,  4,     "integer callback" );
is( $object->_callback_bb, "4",   "KinoSearch::Util::ByteBuf callback" );

my $test_obj = $object->_callback_obj;
isa_ok( $test_obj, "KinoSearch::Util::Obj" );

my %complex_data_structure = (
    a => [ 1,  2,           3,  { ooga => 'booga' } ],
    b => { foo => 'foofoo', bar => 'barbar' },
);

my $transformed = to_perl( to_kino( \%complex_data_structure ) );
is_deeply( $transformed, \%complex_data_structure,
    "transform from Perl to Kino data structures and back" );

my $bread_and_butter = KinoSearch::Util::Hash->new;
$bread_and_butter->store( 'bread', KinoSearch::Util::ByteBuf->new('butter') );
my $salt_and_pepper = KinoSearch::Util::Hash->new;
$salt_and_pepper->store( 'salt', KinoSearch::Util::ByteBuf->new('pepper') );
$complex_data_structure{c} = $bread_and_butter;
$complex_data_structure{d} = $salt_and_pepper;
$transformed               = to_perl( to_kino( \%complex_data_structure ) );
$complex_data_structure{c} = { bread => 'butter' };
$complex_data_structure{d} = { salt => 'pepper' };
is_deeply( $transformed, \%complex_data_structure,
    "handle mixed data structure correctly" );
