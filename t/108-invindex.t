use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 7;

use File::Spec::Functions qw( tmpdir catdir catfile );
use File::Path qw( rmtree );

use KinoSearch::InvIndex;
use KinoSearch::Store::RAMFolder;
use KinoSearch::Store::FSFolder;
use KinoSearch::InvIndexer;
use KinoSearch::Searcher;
use TestSchema;

my $fs_invindex_loc = catdir( tmpdir(), 'bogus_invindex' );

# clean up from previous tests if needed.
rmtree($fs_invindex_loc);

# create a schema instance which we'll keep reusing.
my $schema = TestSchema->new;
my $invindex;

eval {
    $invindex = KinoSearch::InvIndex->open(
        folder => $fs_invindex_loc,
        schema => $schema,
    );
};
like( $@, qr/\Q$fs_invindex_loc/, "opening a non-existent fs dir fails" );

die "$fs_invindex_loc shouldn't exist right now" if -e $fs_invindex_loc;
$invindex = KinoSearch::InvIndex->create(
    folder => $fs_invindex_loc,
    schema => $schema,
);
ok( -d $fs_invindex_loc, "create against an FS loc creates invindex dir" );

$invindex->get_folder->open_outstream('foo');    # touch file
eval {
    $invindex = KinoSearch::InvIndex->create(
        folder => $fs_invindex_loc,
        schema => $schema,
    );
};
like( $@, qr/already/, "create() against a non-empty fs dir fails" );

$invindex = KinoSearch::InvIndex->clobber(
    folder => $fs_invindex_loc,
    schema => $schema,
);
pass("clobber ignores existing fs files");

my $ram_folder = KinoSearch::Store::RAMFolder->new;

$invindex = KinoSearch::InvIndex->open(
    folder => $ram_folder,
    schema => $schema,
);
pass("opening a new ram folder is ok, though unlikely to be useful");

$ram_folder = KinoSearch::Store::RAMFolder->new;
$ram_folder->open_outstream('foo');    # touch file
eval {
    $invindex = KinoSearch::InvIndex->create(
        folder => $ram_folder,
        schema => $schema,
    );
};
like( $@, qr/already/, "create() against a ram folder with files dies" );

$invindex = KinoSearch::InvIndex->clobber(
    folder => $ram_folder,
    schema => $schema,
);
pass("clobber ignores existing files in a RAMFolder");

# clean up
rmtree($fs_invindex_loc);
