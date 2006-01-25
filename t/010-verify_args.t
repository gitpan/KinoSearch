use strict;
use warnings;

use Test::More tests => 3;

BEGIN { use_ok( 'KinoSearch::Util::VerifyArgs', qw( verify_args ) ) }

my %defaults = ( foo => 'FOO', bar => 'BAR' );

sub check {
    verify_args( \%defaults, @_ );
}

my $dest = {};

eval { check( odd => 'number', of => ) };
like( $@, qr/odd/, "An odd number of args chokes verify_args" );
eval { check( bad => 'badness' ) };
like( $@, qr/invalid/i, "An invalid arg chokes verify_args" );
