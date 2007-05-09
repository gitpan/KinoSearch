use strict;
use warnings;

use Test::More tests => 25;

use File::Spec::Functions qw( tmpdir catdir catfile );
use File::Path qw( rmtree );

use KinoSearch::Store::RAMFolder;
use KinoSearch::Store::FSFolder;
use KinoSearch::Store::Lock;
use KinoSearch::Index::IndexFileNames 'filename_from_gen';

my $fs_invindex_loc = catdir( tmpdir(), 'bogus_invindex' );

# clean up from previous tests if needed.
rmtree($fs_invindex_loc);

mkdir $fs_invindex_loc or die "Couldn't mkdir '$fs_invindex_loc': $!";
my $fs_folder = KinoSearch::Store::FSFolder->new( path => $fs_invindex_loc, );

my $king      = "I'm the king of rock.";
my $outstream = $fs_folder->open_outstream('king_of_rock');
$outstream->lu_write( 'a' . bytes::length($king), $king );
$outstream->sclose;

my $ram_folder
    = KinoSearch::Store::RAMFolder->new( path => $fs_invindex_loc, );

ok( $ram_folder->file_exists('king_of_rock'),
    "RAMFolder successfully reads existing FSFolder"
);

for my $folder ( $fs_folder, $ram_folder ) {

    my @files = $folder->list;
    is_deeply( \@files, ['king_of_rock'], "list lists files" );

    my $slurped = $folder->slurp_file('king_of_rock');
    is( $slurped, $king, "slurp_file works" );

    my $lock = KinoSearch::Store::Lock->new(
        agent_id  => '',
        folder    => $folder,
        lock_name => 'lock_robster',
        timeout   => 0,
    );
    my $competing_lock = KinoSearch::Store::Lock->new(
        agent_id  => '',
        folder    => $folder,
        lock_name => 'lock_robster',
        timeout   => 0,
    );

    $lock->obtain;
    ok( $lock->is_locked, "lock is locked" );
    ok( !$competing_lock->obtain, "shouldn't get lock on existing resource" );
    ok( $lock->is_locked, "lock still locked after competing attempt" );

    $lock->release;
    ok( !$lock->is_locked, "release works" );

    $lock->run_while_locked(
        do_body => sub {
            $folder->rename_file( 'king_of_rock', 'king_of_lock' );
        },
    );

    ok( !$folder->file_exists('king_of_rock'),
        "file successfully removed while locked"
    );
    is( $folder->file_exists('king_of_lock'),
        1, "file successfully moved while locked" );

    is( $folder->safe_open_outstream("king_of_lock"),
        undef, "safe open outstream returns undef when file exists" );

    isa_ok(
        $folder->safe_open_outstream("lockit"),
        "KinoSearch::Store::OutStream",
        "safe open outstream succeeds when file doesn't exist"
    );

    $folder->delete_file('king_of_lock');
    ok( !$folder->file_exists('king_of_lock'), "delete_file works" );
}

my $foo_path = catfile( $fs_invindex_loc, 'foo' );
my $cf_path  = catfile( $fs_invindex_loc, '_1.cf' );

for ( $foo_path, $cf_path ) {
    open( my $fh, '>', $_ )
        or die "Couldn't open '$_' for writing: $!";
    print $fh 'stuff';
}

$fs_folder = KinoSearch::Store::FSFolder->new( path => $fs_invindex_loc, );
ok( -e $foo_path, "creating an invindex shouldn't wipe an unrelated file" );

for ( 0 .. 100 ) {
    my $filename = filename_from_gen( '_1', $_, '.stuff' );
    $ram_folder->open_outstream($filename);
}
my $filename = $ram_folder->latest_gen( "_1", ".stuff" );
is( $filename, "_1_2s.stuff", "retrieve latest generation" );

# clean up
rmtree($fs_invindex_loc);
