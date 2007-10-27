use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 3;

use KinoSearch::Index::CompoundFileReader;
use KinoSearch::Index::SegInfos;
use KinoSearch::Index::SegInfo;
use KinoSearch::Util::Hash;
use KinoSearch::Index::IndexFileNames qw( @COMPOUND_EXTENSIONS );

use KinoTestUtils qw( create_invindex );

my $invindex  = create_invindex('a');
my $folder    = $invindex->get_folder;
my $schema    = $invindex->get_schema;
my $seg_infos = KinoSearch::Index::SegInfos->new( schema => $schema );
$seg_infos->read_infos( folder => $folder );
my $seg_info  = $seg_infos->get_info('_1');
my $cf_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_info => $seg_info,
);

my $instream = $cf_reader->open_instream('_1.lex0');
isa_ok( $instream, 'KinoSearch::Store::InStream' );

my $lex_bytecount = $instream->slength;
my $lex_content   = $instream->lu_read("a$lex_bytecount");
my $slurped       = $cf_reader->slurp_file('_1.lex0');
is( $slurped, $lex_content, "slurp_file gets the right bytes" );

my @files
    = sort map {"_1.$_"} ( @COMPOUND_EXTENSIONS, "p0", "lex0", "lexx0" );

my $cf_metadata = $seg_info->extract_metadata('compound_file');

my @cf_entries = sort keys %{ $cf_metadata->{sub_files} };

is_deeply( \@cf_entries, \@files, "get all the right files" );
