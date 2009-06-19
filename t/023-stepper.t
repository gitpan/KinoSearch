use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 1;
use KinoSearch::Test::TestUtils qw( create_index );

my $folder   = create_index( 'a' .. 'c' );
my $schema   = KinoSearch::Test::TestSchema->new;
my $instream = $folder->open_in('seg_1/lexicon-1.dat')
    or die "Can't open instream";
my $outstream = $folder->open_out('dump')
    or die "Can't open outstream";

# Use LexStepper to check Stepper_Dump().
my $term_stepper = KinoSearch::Index::LexStepper->new(
    field         => "content",
    skip_interval => $schema->get_architecture->skip_interval,
);

$term_stepper->dump_to_file( instream => $instream, outstream => $outstream );
$outstream->close;
my $dumped = $folder->slurp_file('dump');
like( $dumped, qr/0\s+a.+1\s+b.+2\s+c/s, "dump_to_file" );
