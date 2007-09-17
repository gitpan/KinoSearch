#!/usr/bin/perl 
use strict;
use warnings;

use lib 't';
use Test::More tests => 2;
use File::Spec::Functions qw( catfile );
use KinoSearchTestInvIndex qw( create_test_invindex path_for_test_invindex );

create_test_invindex();

my $path = path_for_test_invindex();
ok( -d $path, "created invindex directory" );
opendir( my $test_invindex_dh, $path )
    or die "Couldn't opendir '$path': $!";
my @cfs_files = grep {m/\.cfs$/} readdir $test_invindex_dh;
closedir $test_invindex_dh or die "Couldn't closedir '$path': $!";
cmp_ok( scalar @cfs_files, '>', 0, "at least one .cfs file exists" );

