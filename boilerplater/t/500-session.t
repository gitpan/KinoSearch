use strict;
use warnings;

use Test::More tests => 3;

BEGIN { use_ok('Boilerplater::Session') }

my %args = (
    base_dir => 't/bp',
    dest_dir => 't/r',
    header   => "HEAD_START\n",
    footer   => "THIS_LOOKS_LIKE_THE_END\n",
);

my $session = Boilerplater::Session->new(%args);
isa_ok( $session, "Boilerplater::Session" );

eval { my $death = Boilerplater::Session->new( %args, extra_arg => undef ) };
like( $@, qr/extra_arg/, "Extra arg kills constructor" );
