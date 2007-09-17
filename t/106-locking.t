#!perl
use strict;
use warnings;
use Time::HiRes qw( sleep );
use Test::More;

BEGIN {
    if ( $^O =~ /mswin/i ) {
        plan( 'skip_all', "fork on Windows not supported by KS" );
    }
    else {
        plan( tests => 3 );
    }
    use_ok 'KinoSearch::Store::FSLock';
}

use KinoSearch::Store::FSInvIndex;

Dead_locks_are_removed: {
    my $lock_path = "$KinoSearch::Store::FSInvIndex::LOCK_DIR/test-foo";

    # Remove any existing lockfile
    unlink $lock_path;
    die "Can't unlink '$lock_path'" if -e $lock_path;

    # Fake index for test simplicity
    my $mock_index = MockIndex->new( prefix => 'test' );

    sub make_lock {
        my $lock = KinoSearch::Store::FSLock->new(
            invindex  => $mock_index,
            lock_name => 'foo',
        );
        $lock->obtain;
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

    eval { make_lock() };
    warn $@ if $@;
    ok( !$@, 'second lock attempt did not die' );
}

package MockIndex;
use strict;
use warnings;

sub new {
    my ( $class, %args ) = @_;
    bless \%args, $class;
}

sub get_path        {"bar"}
sub get_lock_prefix { $_[0]->{prefix} }

