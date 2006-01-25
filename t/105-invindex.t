use strict;
use warnings;

use Test::More tests => 19;

use File::Spec::Functions qw( tmpdir catdir );
use File::Path qw( rmtree );

BEGIN {
    use_ok('KinoSearch::Store::RAMInvIndex');
    use_ok('KinoSearch::Store::FSInvIndex');
}

my $fs_invindex_loc = catdir( tmpdir, 'test_invindex' );

my $fs_invindex = KinoSearch::Store::FSInvIndex->new(
    create => 1,
    path   => $fs_invindex_loc,
);

my $king      = "I'm the king of rock.";
my $outstream = $fs_invindex->open_outstream('king_of_rock');
$outstream->lu_write( 'a' . bytes::length($king), $king );
$outstream->close;

my $ram_invindex = KinoSearch::Store::RAMInvIndex->new(
    create => 1,
    path   => $fs_invindex_loc,
);

ok( $ram_invindex->file_exists('king_of_rock'),
    "RAMInvIndex successfully reads existing FSInvIndex"
);

for my $invindex ( $fs_invindex, $ram_invindex ) {

    my @files = $invindex->list;
    is_deeply( \@files, ['king_of_rock'], "list lists files" );

    my $slurped = $invindex->slurp_file('king_of_rock');
    is( $slurped, $king, "slurp_file works" );

    my $lock = $invindex->make_lock(
        lock_name => 'lock_robster',
        timeout   => 0,
    );
    my $competing_lock = $invindex->make_lock(
        lock_name => 'lock_robster',
        timeout   => 0,
    );

    $lock->obtain;

    eval { $competing_lock->obtain };
    like( $@, qr/get lock/, "shouldn't get lock on existing resource" );

    ok( $lock->is_locked, "lock is locked" );

    $lock->release;
    ok( !$lock->is_locked, "release works" );

    $invindex->run_while_locked(
        lock_name => 'lock_robster',
        timeout   => 1000,
        do_body   => sub {
            $invindex->rename_file( 'king_of_rock', 'king_of_lock' );
        },
    );

    ok( !$invindex->file_exists('king_of_rock'),
        "file successfully removed while locked"
    );
    is( $invindex->file_exists('king_of_lock'),
        1, "file successfully moved while locked" );

    $invindex->delete_file('king_of_lock');
    ok( !$invindex->file_exists('king_of_lock'), "delete_file works" );
}

# clean up
rmtree($fs_invindex_loc);

