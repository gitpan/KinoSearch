use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 12;

use File::Spec::Functions qw( catfile );
use File::Path qw( rmtree );
use Fcntl;

use KinoSearch::InvIndex;
use KinoSearch::Store::RAMFolder;
use KinoSearch::Store::FSFolder;
use KinoSearch::InvIndexer;
use KinoSearch::Searcher;
use TestSchema;
use KinoTestUtils qw( init_test_invindex_loc );

my $fs_invindex_loc = init_test_invindex_loc();
my $fs_seg_file_loc = catfile( $fs_invindex_loc, 'segments_1.yaml' );

# clean up from previous tests if needed.
clean_up_fs_invindex();

# create a schema instance which we'll keep reusing.
my $schema = TestSchema->new;
my $invindex;
my $folder;

$invindex = KinoSearch::InvIndex->clobber(
    folder => $fs_invindex_loc,
    schema => $schema,
);
ok( -e $fs_seg_file_loc, "clobber with path passed to folder param" );
clean_up_fs_invindex();

mkdir $fs_invindex_loc or die "can't mkdir $fs_invindex_loc: $!";
$folder = KinoSearch::Store::FSFolder->new( path => $fs_invindex_loc ),
    $invindex = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => $schema,
    );
ok( -e $fs_seg_file_loc, "clobber with FSFolder passed to folder param" );
clean_up_fs_invindex();
undef $folder;

mkdir $fs_invindex_loc or die "can't mkdir $fs_invindex_loc: $!";
my $kino_file     = catfile( $fs_invindex_loc, 'segments_1000.yaml' );
my $non_kino_file = catfile( $fs_invindex_loc, 'foo' );
touch_fs_file($kino_file);
touch_fs_file($non_kino_file);
$folder = KinoSearch::Store::FSFolder->new( path => $fs_invindex_loc ),
    $invindex = KinoSearch::InvIndex->clobber(
    folder => $fs_invindex_loc,
    schema => $schema,
    );
ok( -e $non_kino_file, "clobber doesn't take out non-KinoSearch files" );
ok( !-e $kino_file, "clobber kills of old KinoSearch files" );
clean_up_fs_invindex();

$invindex = KinoSearch::InvIndex->open(
    folder => $fs_invindex_loc,
    schema => $schema,
);
pass("open opens existing index when supplied with path");

$folder = KinoSearch::Store::FSFolder->new( path => $fs_invindex_loc ),
    $invindex = KinoSearch::InvIndex->open(
    folder => $folder,
    schema => $schema,
    );
pass("open opens existing index when supplied with folder");

clean_up_fs_invindex();
$invindex = KinoSearch::InvIndex->open(
    folder => $fs_invindex_loc,
    schema => $schema,
);
ok( -d $fs_invindex_loc, "open creates new directory if one didn't exist" );

$invindex = KinoSearch::InvIndex->read(
    folder => $fs_invindex_loc,
    schema => $schema,
);
pass("read opens existing index when supplied with path");

$folder = KinoSearch::Store::FSFolder->new( path => $fs_invindex_loc ),
    $invindex = KinoSearch::InvIndex->read(
    folder => $fs_invindex_loc,
    schema => $schema,
    );
pass("read opens existing index when supplied with folder");

clean_up_fs_invindex();
eval {
    $invindex = KinoSearch::InvIndex->read(
        folder => $fs_invindex_loc,
        schema => $schema,
    );
};
like( $@, qr/directory/i, "read fails when supplied path is invalid" );

$folder = KinoSearch::Store::RAMFolder->new;
$folder->open_outstream('foo');
$folder->open_outstream('segments_1000.yaml');
$invindex = KinoSearch::InvIndex->clobber(
    folder => $folder,
    schema => $schema,
);
ok( $folder->file_exists('foo'),
    "clobber doesn't take out non-KinoSearch files in RAMFolder" );
ok( !$folder->file_exists('segments_1000.yaml'),
    "clobber kills of old KinoSearch files in RAMFolder"
);

sub clean_up_fs_invindex {
    rmtree($fs_invindex_loc);
    die "$fs_invindex_loc shouldn't exist right now" if -e $fs_invindex_loc;
}

sub touch_fs_file {
    my $filepath = shift;
    return if -e $filepath;
    sysopen( my $fh, $filepath, O_CREAT | O_EXCL | O_WRONLY ) 
        or die "can't open '$filepath': $!";
}
