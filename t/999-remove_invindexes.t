use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 1;
use KinoTestUtils qw( remove_working_dir working_dir );

remove_working_dir();
ok( !-e working_dir(), "working_dir is no more" );

