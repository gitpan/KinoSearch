use strict;
use warnings;

use Test::More tests => 2;

BEGIN { use_ok( 'KinoSearch', 'K_DEBUG' ) }

ok( !K_DEBUG, "DEBUG mode should be disabled" );

