use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 13;
use File::Spec::Functions qw( catfile );
use KinoSearch::Test::TestUtils qw( init_test_index_loc );
use JSON::XS qw();

my $fs_index_loc = init_test_index_loc();
my $file_loc = catfile( $fs_index_loc, 'seg_9/biff' );

my $folder  = KinoSearch::Store::FSFolder->new( path => $fs_index_loc );
my $schema  = KinoSearch::Test::TestSchema->new;
my $segment = KinoSearch::Index::Segment->new( number => 9 );
$folder->mkdir("seg_9");
write_file( $folder, "seg_9/biff",  "biff biff" );
write_file( $folder, "seg_9/boffo", "boffo boffo" );
$folder->finish_segment( $segment->get_name );
ok( $folder->real_exists('seg_9/cf.dat'),      'cf file exists' );
ok( $folder->real_exists('seg_9/cfmeta.json'), 'cfmeta file exists' );
ok( !-f $file_loc,
    'original seg file zapped, now that its content has been consolidated' );
ok( $folder->exists('seg_9/biff'),
    "consolidated file available as virtual file" );

my $json        = $folder->slurp_file('seg_9/cfmeta.json');
my $cf_metadata = JSON::XS->new->decode($json);
my $offsets_ok  = 1;
while ( my ( $filename, $stats ) = each %{ $cf_metadata->{files} } ) {
    if ( $stats->{offset} % 8 != 0 ) {
        fail("offset $stats->{offset} for $filename not a multiple of 8");
        $offsets_ok = 0;
        last;
    }
}
if ($offsets_ok) { pass("All file offsets are multiples of 8."); }

$folder->delete('seg_9/cfmeta.json')
    or die "Can't delete 'seg_9/cfmeta.json'";
ok( !$folder->exists('seg_9/cfmeta.json'),
    "cfmeta file successfully zapped" );
$folder = KinoSearch::Store::FSFolder->new( path => $fs_index_loc );
ok( !$folder->exists('seg_9/biff'),
    "once cfmeta file zapped, no more access to virtual files" );

$file_loc = catfile( $fs_index_loc, 'seg_9/banana' );
write_file( $folder, "seg_9/banana", "banana banana" );
ok( -f $file_loc, "segment data file exists prior to consolidation" );

write_file( $folder, "seg_9/biff",  "biff biff" );
write_file( $folder, "seg_9/boffo", "boffo boffo" );
$folder->finish_segment( $segment->get_name );
ok( $folder->real_exists('seg_9/cfmeta.json'),
    'Consolidation completes if cfmeta file deleted'
);
ok( !-f $file_loc,                         "real file is gone" );
ok( !$folder->real_exists("seg_9/banana"), "real_exists knows file is gone" );
ok( $folder->exists('seg_9/banana'),       "virtual file created" );

SKIP: {
    skip( "known leaks", 1 ) if $ENV{KINO_VALGRIND};
    eval { $folder->finish_segment( $segment->get_name ); };
    like( $@, qr/seg_9/, "Can't consolidate same segment twice" );
}

sub write_file {
    my ( $fold, $filename, $content ) = @_;
    my $outstream = $fold->open_out($filename) or die "Can't open $filename";
    $outstream->print($content);
    $outstream->close;
}
