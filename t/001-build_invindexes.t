use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 2;
use File::Spec::Functions qw( catfile );
use KinoTestUtils qw( create_uscon_invindex path_for_test_invindex );

create_uscon_invindex();

my $path = path_for_test_invindex();
ok( -d $path, "created invindex directory" );
opendir( my $test_invindex_dh, $path )
    or die "Couldn't opendir '$path': $!";
my @cf_files = grep {m/\.cf$/} readdir $test_invindex_dh;
closedir $test_invindex_dh or die "Couldn't closedir '$path': $!";
cmp_ok( scalar @cf_files, '>', 0, "at least one .cf file exists" );

