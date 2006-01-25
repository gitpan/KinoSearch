#!/usr/bin/perl 
use strict;
use warnings;

use lib 't';
use Test::More tests => 2;
use File::Spec::Functions qw( catfile );
use KinoSearchTestInvIndex qw( create_test_invindex );

create_test_invindex();

ok( -d 'test_invindex', "created invindex directory" );
ok( -f catfile( 'test_invindex', '_1.cfs' ), 
    ".cfs file exists" );

