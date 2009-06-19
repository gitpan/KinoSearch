use strict;
use warnings;

use Test::More tests => 7;

BEGIN { use_ok('Boilerplater::ParamList') }
use Boilerplater::Type;
use Boilerplater::Parser;

my $parser = Boilerplater::Parser->new;
$parser->parcel_definition('parcel Boil;')
    or die "failed to process parcel_definition";

my $param_list = $parser->param_list("(Obj *self, int num)");
isa_ok( $param_list, "Boilerplater::ParamList" );
ok( !$param_list->variadic, "not variadic" );
is( $param_list->to_c, 'boil_Obj* self, int num', "to_c" );

$param_list = $parser->param_list("(Obj *self=NULL, int num, ...)");
ok( $param_list->variadic, "variadic" );
is_deeply(
    $param_list->get_initial_values,
    [ "NULL", undef ],
    "initial_values"
);
is( $param_list->to_c, 'boil_Obj* self, int num, ...', "to_c" );
