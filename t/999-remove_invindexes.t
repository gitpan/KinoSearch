use strict;
use warnings;
use lib 'buildlib';

use File::Path qw( rmtree );
use Test::More tests => 1;

use KinoTestUtils qw( path_for_test_invindex );

rmtree( path_for_test_invindex() );

ok( 1, "dummy test" );


