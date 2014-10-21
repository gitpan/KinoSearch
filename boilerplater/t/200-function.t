use strict;
use warnings;

use Test::More tests => 4;

BEGIN { use_ok('Boilerplater::Function') }
use Boilerplater::Parser;
use Boilerplater::Parcel;

my $parser = Boilerplater::Parser->new;
$parser->parcel_definition('parcel Boil;')
    or die "failed to process parcel_definition";

my %args = (
    parcel      => 'Boil',
    return_type => $parser->type('Obj*'),
    class_name  => 'Boil::Foo',
    class_cnick => 'Foo',
    param_list  => $parser->param_list('(i32_t some_num)'),
    micro_sym   => 'return_an_obj',
);

my $func = Boilerplater::Function->new(%args);
isa_ok( $func, "Boilerplater::Function" );

eval { my $death = Boilerplater::Function->new( %args, extra_arg => undef ) };
like( $@, qr/extra_arg/, "Extra arg kills constructor" );

eval { Boilerplater::Function->new( %args, micro_sym => 'Uh_Oh' ); };
like( $@, qr/Uh_Oh/, "invalid micro_sym kills constructor" );

