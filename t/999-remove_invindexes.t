#!/usr/bin/perl 
use strict;
use warnings;

use lib 't';
use File::Path qw( rmtree );
use Test::More tests => 1;

use KinoSearchTestInvIndex qw( path_for_test_invindex );

rmtree( path_for_test_invindex() );

ok( 1, "dummy test" );


