use strict;
use warnings;

use Test::More tests => 3;

BEGIN { use_ok( 'KinoSearch', 'K_DEBUG' ) }

ok( !K_DEBUG, "DEBUG mode should be disabled" );
ok( !KinoSearch::memory_debugging_enabled(),
    "Memory debugging should be disabled"
);

