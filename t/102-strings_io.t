use strict;
use warnings;

use Test::More tests => 3;
use KinoSearch::Test;

my $folder = KinoSearch::Store::RAMFolder->new;
my ( @items, $packed, $template, $buf, $out, $in, $correct );

$out = $folder->open_out('raw_c64s') or die "Can't open file";
$out->write_c64(10000);
$out->close;
$in = $folder->open_in('raw_c64s');
$in->read_raw_c64($buf);
$correct = $folder->slurp_file('raw_c64s');
is( $buf, $correct, "read_raw_c64" );

$out = $folder->open_out('read_bytes') or die "Can't open file";
$out->print("mint");
$out->close;
$in  = $folder->open_in('read_bytes');
$buf = "funny";
$in->read_bytes( $buf, 1 );
is( $buf, "munny", 'read_bytes' );

$out = $folder->open_out('read_byteso') or die "Can't open file";
$out->print("cute");
$out->close;
$in  = $folder->open_in('read_byteso');
$buf = "buzz";
$in->read_byteso( $buf, 4, 3 );
is( $buf, "buzzcut", 'read_byteso' );
