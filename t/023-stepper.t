use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 1;

use KinoTestUtils qw( create_invindex );
use KinoSearch::Index::TermStepper;
use KinoSearch::Index::SegInfos;

my $invindex = create_invindex( 'a' .. 'c' );

my $folder    = $invindex->get_folder;
my $schema    = $invindex->get_schema;
my $seg_infos = KinoSearch::Index::SegInfos->new( schema => $schema );
$seg_infos->read_infos( folder => $folder );
my $seg_info  = $seg_infos->get_info('_1');
my $cf_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_info => $seg_info,
);

my $instream  = $cf_reader->open_instream('_1.lex0');
my $outstream = $folder->open_outstream('dump');

# use TermStepper to check Stepper_Dump()
my $term_stepper
    = KinoSearch::Index::TermStepper->new( "content", $schema->index_interval,
    0 );

$term_stepper->dump_to_file( $instream, $outstream );
$outstream->sclose;
my $dumped = $folder->slurp_file('dump');
like( $dumped, qr/content:a.+content:b.+content:c/s, "dump_to_file" );

