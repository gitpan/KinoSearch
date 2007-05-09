use strict;
use warnings;

use Test::More tests => 1;

use KinoSearch::Util::MemoryPool;

ok( KinoSearch::Util::MemoryPool::run_tests(),
    "run_tests should return true" );
