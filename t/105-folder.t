use strict;
use warnings;

use Test::More tests => 22;

use File::Spec::Functions qw( tmpdir catdir catfile );
use File::Path qw( rmtree );

BEGIN {
    use_ok('KinoSearch::Store::RAMFolder');
    use_ok('KinoSearch::Store::FSFolder');
    use_ok( 'KinoSearch::Index::IndexFileNames' => 'filename_from_gen' );
}

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

    my $lock = $folder->make_lock(
        lock_name => 'lock_robster',
        timeout   => 0,
    );
    my $competing_lock = $folder->make_lock(
        lock_name => 'lock_robster',
        timeout   => 0,
    );

    $lock->obtain;

SKIP: {
        if ( $ENV{KINO_VALGRIND} ) {
            skip( "known leak", 1 );
        }
        else {
            eval { $competing_lock->obtain };
        }
        like( $@, qr/get lock/, "shouldn't get lock on existing resource" );
    }

    ok( $lock->is_locked, "lock is locked" );

    $lock->release;
    ok( !$lock->is_locked, "release works" );

    $folder->run_while_locked(
        lock_name => 'lock_robster',
        timeout   => 1000,
        do_body   => sub {
            $folder->rename_file( 'king_of_rock', 'king_of_lock' );
        },
    );

    ok( !$folder->file_exists('king_of_rock'),
        "file successfully removed while locked"
    );
    is( $folder->file_exists('king_of_lock'),
        1, "file successfully moved while locked" );

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
