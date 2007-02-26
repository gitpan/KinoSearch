use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 4;

BEGIN {
    use_ok( "KinoSearch::Index::IndexFileNames" =>
            qw( filename_from_gen gen_from_file_name unused_files ) );
}

use KinoTestUtils qw( create_invindex );
use KinoSearch::Index::SegInfos;

my $invindex = create_invindex(qw( a b c ));
my $folder   = $invindex->get_folder;

sub touch {
    my ( $invi, $fname ) = @_;
    my $outstream = $invi->open_outstream($fname);
    $outstream->sclose;
}

my $seg_infos = KinoSearch::Index::SegInfos->new;
$seg_infos->read_infos($folder);

touch( $folder, "_234.p25" );
my @files = $folder->list;
my @unused = unused_files( \@files, $seg_infos );
is_deeply( \@unused, ['_234.p25'], "unused file" );

touch( $folder, "foo" );
@files = $folder->list;
@unused = unused_files( \@files, $seg_infos );
is_deeply( \@unused, ['_234.p25'], "non ks file ignored" );

$folder->delete_file("_234.p25");
my @expected = ("segments_2.yaml");
for ( 3 .. 50 ) {
    my $filename = filename_from_gen( "segments", $_, ".yaml" );
    push @expected, $filename;
    touch( $folder, $filename );
}
@expected = sort @expected;
touch( $folder, "segments_999.yaml" );
@files  = $folder->list;
@unused = unused_files( \@files, $seg_infos );
@unused = sort @unused;
is_deeply( \@unused, \@expected,
    "unused_files handles generational files correctly" );

