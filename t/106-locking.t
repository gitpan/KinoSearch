use strict;
use warnings;

use Time::HiRes qw( sleep );
use Test::More;
use File::Spec::Functions qw( tmpdir catdir catfile );
use File::Path qw( rmtree );

BEGIN {
    if ( $^O =~ /mswin/i ) {
        plan( 'skip_all', "fork on Windows not supported by KS" );
    }
    else {
        plan( tests => 3 );
    }
}

use KinoSearch::Store::Lock;
use KinoSearch::Store::FSFolder;

my $path = catdir( tmpdir(), "lock_test_invindex" );
rmtree($path);
mkdir $path or die "Can't mkdir '$path': $!";

Dead_locks_are_removed: {
    my $lock_path = catfile( $path, 'foo.lock' );

    # Remove any existing lockfile
    unlink $lock_path;
    die "Can't unlink '$lock_path'" if -e $lock_path;

    my $folder = KinoSearch::Store::FSFolder->new( path => $path );

    sub make_lock {
        my $lock = KinoSearch::Store::Lock->new(
            timeout   => 0,
            folder    => $folder,
            lock_name => 'foo',
            agent_id  => '',
            @_
        );
        $lock->clear_stale;
        $lock->obtain or die "no dice";
        return $lock;
    }

    # Fork a process that will create a lock and then exit
    if ( fork() == 0 ) {    # child
                            # double fork to daemonize
        if ( fork() == 0 ) {    # sub child
            make_lock();
        }
        exit;
    }

    # wait for the daemon to secure the lock, then a little longer for exit
    for ( 0 .. 20 ) {
        sleep .1 unless -e $lock_path;
    }
    sleep .1;
    ok( -e $lock_path, "daemon secured lock" );

    eval { make_lock( agent_id => 'somebody_else' ) };
    like( $@, qr/no dice/, "different agent_id fails to get lock" );

    eval { make_lock() };
    warn $@ if $@;
    ok( !$@, 'second lock attempt did not die' );

}
