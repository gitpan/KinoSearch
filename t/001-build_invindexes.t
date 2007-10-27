use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 4;
use File::Spec::Functions qw( catfile );
use KinoTestUtils qw( 
    working_dir
    create_working_dir
    remove_working_dir
    create_uscon_invindex 
    persistent_test_invindex_loc 
);

remove_working_dir();
ok( !-e working_dir(), "Working dir doesn't exist" );

create_working_dir();
my $mode = ( stat( working_dir() ) )[2] & 07777;
if ( $mode == 0700 ) {
    pass("Working dir successfully created  with correct permissions");
}
else {
    BAIL_OUT( "Unsafe to continue: working dir '" . working_dir()
            . "' not owned exclusively by this user" );
}

create_uscon_invindex();

my $path = persistent_test_invindex_loc();
ok( -d $path, "created invindex directory" );
opendir( my $test_invindex_dh, $path )
    or die "Couldn't opendir '$path': $!";
my @cf_files = grep {m/\.cf$/} readdir $test_invindex_dh;
closedir $test_invindex_dh or die "Couldn't closedir '$path': $!";
cmp_ok( scalar @cf_files, '>', 0, "at least one .cf file exists" );

