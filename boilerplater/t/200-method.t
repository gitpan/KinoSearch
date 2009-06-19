use strict;
use warnings;

use Test::More tests => 6;

BEGIN { use_ok('Boilerplater::Method') }
use Boilerplater::Parser;

my $parser = Boilerplater::Parser->new;
$parser->parcel_definition('parcel Boil;')
    or die "failed to process parcel_definition";

my %args = (
    parcel      => 'Boil',
    return_type => $parser->type('Obj*'),
    class_name  => 'Boil::Foo',
    class_cnick => 'Foo',
    param_list  => $parser->param_list('(Foo *self)'),
    micro_sym   => 'return_an_obj',
    macro_name  => 'Return_An_Obj',
    exposure    => 'parcel',
);

my $method = Boilerplater::Method->new(%args);
isa_ok( $method, "Boilerplater::Method" );

eval { my $death = Boilerplater::Method->new( %args, extra_arg => undef ) };
like( $@, qr/extra_arg/, "Extra arg kills constructor" );

eval { Boilerplater::Method->new( %args, macro_name => 'return_an_obj' ); };
like( $@, qr/macro_name/, "Invalid macro name kills constructor" );

ok( $method->parcel,  "parcel acl" );
ok( !$method->public, "not public acl" );
