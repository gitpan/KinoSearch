use strict;
use warnings;

use Test::More tests => 6;

use KinoSearch::Store::LockFactory;
use KinoSearch::Store::RAMFolder;

my $folder = KinoSearch::Store::RAMFolder->new;

my $lock_factory = KinoSearch::Store::LockFactory->new(
    agent_id => 'me',
    folder   => $folder,
);

my $lock = $lock_factory->make_lock(
    lock_name => 'angie',
    timeout   => 1000,
);
is( ref($lock),           'KinoSearch::Store::Lock', "make_lock" );
is( $lock->get_lock_name, "angie",                   "correct lock name" );
is( $lock->get_agent_id,  "me",                      "correct agent id" );

$lock = $lock_factory->make_shared_lock(
    lock_name => 'fred',
    timeout   => 0,
);
is( ref($lock), 'KinoSearch::Store::SharedLock', "make_shared_lock" );
is( $lock->get_lock_name, "fred", "correct lock name" );
is( $lock->get_agent_id,  "me",   "correct agent id" );
