use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 2;
use KinoSearch::Test::TestUtils qw( create_index );

my $folder = create_index( "a", "a b" );

my $snapshot = KinoSearch::Index::Snapshot->new;
$snapshot->read_file( folder => $folder );

my $evil_twin   = $snapshot->load( $snapshot->dump );
my $files       = [ sort @{ $snapshot->list } ];
my $duped_files = [ sort @{ $evil_twin->list } ];
is_deeply( $files, $duped_files, "dump/load round trip for files" );

$snapshot->write_file( folder => $folder );
$evil_twin = KinoSearch::Index::Snapshot->new->read_file( folder => $folder );
$files = [ sort @{ $snapshot->list } ];
$duped_files = [ sort @{ $evil_twin->list } ];
is_deeply( $files, $duped_files, "write_file/read_file round trip" );

