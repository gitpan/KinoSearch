#!/usr/bin/perl 
use strict;
use warnings;

use File::Path qw( rmtree );
use Test::More tests => 1;

rmtree 'test_invindex';

ok( 1, "dummy test" );


