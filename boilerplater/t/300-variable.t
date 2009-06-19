use strict;
use warnings;

use Test::More tests => 11;
use Boilerplater::Type;
use Boilerplater::Parser;

BEGIN { use_ok('Boilerplater::Variable') }

my $parser = Boilerplater::Parser->new;
$parser->parcel_definition('parcel Boil;')
    or die "failed to process parcel_definition";

sub new_type { $parser->type(shift) }

my $var = Boilerplater::Variable->new(
    micro_sym => 'foo',
    type      => new_type('int**'),
    exposure  => 'parcel',
);
isa_ok( $var, "Boilerplater::Variable" );
ok( $var->parcel,  "parcel acl" );
ok( !$var->public, "not public acl" );

eval {
    my $death = Boilerplater::Variable->new(
        micro_sym => 'foo',
        type      => new_type('int'),
        extra_arg => undef,
    );
};
like( $@, qr/extra_arg/, "Extra arg kills constructor" );

eval { my $death = Boilerplater::Variable->new( micro_sym => 'foo' ) };
like( $@, qr/type/, "type is required" );
eval { my $death = Boilerplater::Variable->new( type => new_type('i32_t') ) };
like( $@, qr/micro_sym/, "micro_sym is required" );

$var = Boilerplater::Variable->new(
    micro_sym => 'foo',
    type      => new_type('float*')
);
is( $var->to_c,          'float* foo',  "to_c" );
is( $var->c_declaration, 'float* foo;', "declaration" );
ok( $var->local, "default to local access" );

$var = Boilerplater::Variable->new(
    micro_sym => 'foo',
    type      => new_type('float[1]')
);
is( $var->to_c, 'float foo[1]',
    "to_c appends array to var name rather than type specifier" );
