use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 25;
use File::Spec::Functions qw( catfile );
use Fcntl;
use KinoSearch::Test::TestUtils qw( init_test_index_loc );
use KinoSearch::Util::StringHelper qw( to_base36 );

my $fs_index_loc = init_test_index_loc();
my $fs_folder    = KinoSearch::Store::FSFolder->new( path => $fs_index_loc, );
my $ram_folder   = KinoSearch::Store::RAMFolder->new;

my $king = "I'm the king of rock.";
for my $folder ( $fs_folder, $ram_folder ) {
    my $outstream = $folder->open_out('king_of_rock')
        or die KinoSearch->error;
    $outstream->print($king);
    $outstream->close;
}

for my $folder ( $fs_folder, $ram_folder ) {

    my $files = $folder->list_r;
    is_deeply( $files, ['king_of_rock'], "list lists files" );

    $folder->mkdir('queen');
    ok( $folder->exists('queen'), "mkdir" );

    my $slurped = $folder->slurp_file('king_of_rock');
    is( $slurped, $king, "slurp_file works" );

    my $lock = KinoSearch::Store::LockFileLock->new(
        host    => '',
        folder  => $folder,
        name    => 'lock_robster',
        timeout => 0,
    );
    my $competing_lock = KinoSearch::Store::LockFileLock->new(
        host    => '',
        folder  => $folder,
        name    => 'lock_robster',
        timeout => 0,
    );

    $lock->obtain;
    ok( $lock->is_locked,         "lock is locked" );
    ok( !$competing_lock->obtain, "shouldn't get lock on existing resource" );
    ok( $lock->is_locked, "lock still locked after competing attempt" );

    $lock->release;
    ok( !$lock->is_locked, "release works" );

    $lock->obtain;
    $folder->rename( from => 'king_of_rock', to => 'king_of_lock' );
    $lock->release;

    ok( !$folder->exists('king_of_rock'),
        "file successfully removed while locked"
    );
    is( $folder->exists('king_of_lock'),
        1, "file successfully moved while locked" );

    is( $folder->open_out("king_of_lock"),
        undef, "open_out returns undef when file exists" );

    isa_ok(
        $folder->open_out("lockit"),
        "KinoSearch::Store::OutStream",
        "open_out succeeds when file doesn't exist"
    );

    $folder->delete('king_of_lock');
    ok( !$folder->exists('king_of_lock'), "Delete()" );
}

my $foo_path = catfile( $fs_index_loc, 'foo' );
my $cf_path  = catfile( $fs_index_loc, '_1.cf' );

for ( $foo_path, $cf_path ) {
    unlink $_;
    sysopen( my $fh, $_, O_CREAT | O_EXCL | O_WRONLY )
        or die "Couldn't open '$_' for writing: $!";
    print $fh 'stuff';
}

$fs_folder = KinoSearch::Store::FSFolder->new( path => $fs_index_loc, );
ok( -e $foo_path, "creating an FSFolder shouldn't wipe an unrelated file" );

for ( 0 .. 100 ) {
    my $filename = '_1-' . to_base36($_) . '.stuff';
    $ram_folder->open_out($filename) or die KinoSearch->error;
}
