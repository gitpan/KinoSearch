use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 5;
use File::Spec::Functions qw( catfile );

BEGIN {
    use_ok('KinoSearch::Index::CompoundFileReader');
    use_ok( 'KinoSearch::Index::IndexFileNames', qw( @COMPOUND_EXTENSIONS ) );
}

use KinoTestUtils qw( create_invindex );
use KinoSearch::Index::SegInfos;
use KinoSearch::Index::SegInfo;
use KinoSearch::Util::Hash;

my $invindex  = create_invindex('a');
my $folder    = $invindex->get_folder;
my $schema    = $invindex->get_schema;
my $seg_infos = KinoSearch::Index::SegInfos->new( schema => $schema );
$seg_infos->read_infos($folder);
my $seg_info  = $seg_infos->get_info('_1');
my $cf_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_info => $seg_info,
);

my $instream = $cf_reader->open_instream('_1.tl0');
isa_ok( $instream, 'KinoSearch::Store::InStream' );

my $tl_bytecount = $instream->slength;
my $tl_content   = $instream->lu_read("a$tl_bytecount");
my $slurped      = $cf_reader->slurp_file('_1.tl0');
is( $slurped, $tl_content, "slurp_file gets the right bytes" );

my @files = sort map {"_1.$_"} ( @COMPOUND_EXTENSIONS, "p0", "tl0", "tlx0" );

my $cf_metadata = $seg_info->extract_metadata('compound_file');

my @cf_entries = sort keys %{ $cf_metadata->{sub_files} };

is_deeply( \@cf_entries, \@files, "get all the right files" );

