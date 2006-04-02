#!/usr/bin/perl 
use strict;
use warnings;

use lib 't';
use Test::More tests => 2;
use File::Spec::Functions qw( catfile );
use KinoSearchTestInvIndex qw( create_test_invindex );

create_test_invindex();

ok( -d 'test_invindex', "created invindex directory" );
opendir( TEST_INVINDEX_DIR, 'test_invindex' ) or die $!;
my @cfs_files = grep {m/\.cfs$/} readdir TEST_INVINDEX_DIR;
is( scalar @cfs_files, 1, "one .cfs file exists" );

