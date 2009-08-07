use strict;
use warnings;

use Test::More tests => 14;
use KinoSearch::Test;

my $folder = KinoSearch::Store::RAMFolder->new;

my $lock = KinoSearch::Store::SharedLock->new(
    folder   => $folder,
    name     => 'ness',
    timeout  => 0,
    hostname => 'nessie',
);

ok( !$lock->is_locked, "not locked yet" );

ok( $lock->obtain,                  "obtain" );
ok( $lock->is_locked,               "is_locked" );
ok( $folder->exists('ness-1.lock'), "lockfile exists" );

my $another_lock = KinoSearch::Store::SharedLock->new(
    folder   => $folder,
    name     => 'ness',
    timeout  => 0,
    hostname => 'nessie',
);
ok( $another_lock->obtain, "got a second lock on the same resource" );

$lock->release;
ok( $lock->is_locked,
    "first lock released but still is_locked because of other lock" );

my $ya_lock = KinoSearch::Store::SharedLock->new(
    folder   => $folder,
    name     => 'ness',
    timeout  => 0,
    hostname => 'nessie',
);
ok( $ya_lock->obtain, "got yet another lock" );

ok( $lock->obtain, "got first lock again" );
is( $lock->get_filename, "ness-3.lock",
    "first lock uses a different filename now" );

# Rewrite lock file to spec a different pid.
my $content = $folder->slurp_file("ness-3.lock");
$content =~ s/$$/123456789/;
$folder->delete('ness-3.lock') or die "Can't delete 'ness-3.lock'";
my $outstream = $folder->open_out('ness-3.lock') or die "Can't open file";
$outstream->print($content);
$outstream->close;

$lock->release;
$another_lock->release;
$ya_lock->release;

ok( $lock->is_locked, "failed to release a lock with a different pid" );
$lock->clear_stale;
ok( !$lock->is_locked, "clear_stale" );

ok( $lock->obtain,    "got lock again" );
ok( $lock->is_locked, "it's locked" );

# Rewrite lock file to spec a different hostname.
$content = $folder->slurp_file("ness-1.lock");
$content =~ s/nessie/sting/;
$folder->delete('ness-1.lock') or die "Can't delete 'ness-1.lock'";
$outstream = $folder->open_out('ness-1.lock') or die "Can't open file";
$outstream->print($content);
$outstream->close;

$lock->release;
ok( $lock->is_locked, "don't delete lock belonging to another hostname" );
