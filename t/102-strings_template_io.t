use strict;
use warnings;

use Test::More tests => 6;

use KinoSearch::Store::RAMFolder;

my $folder = KinoSearch::Store::RAMFolder->new;
my ( @items, $packed, $template );

sub check_io {
    my ( $filename, $tpt ) = ( shift, shift );
    my $outstream = $folder->open_outstream($filename);
    $outstream->lu_write( $tpt, @_ );
    $outstream->sclose;
    my $instream = $folder->open_instream($filename);
    my @got      = $instream->lu_read($tpt);
    is_deeply( \@got, \@_, $filename );
}

my @chars = ( qw( a b c d 1 ), "\n", "\0", " ", " ", "\xf0\x9d\x84\x9e" );

for ( 0, 22, 300 ) {
    @items = ( 'a' x $_ );
    check_io( "string of length $_", 'T', @items );
}

{
    @items = ();
    for ( 1 .. 50 ) {
        my $string_len = int( rand() * 5 );
        my $str        = '';
        $str .= $chars[ rand @chars ] for 1 .. $string_len;
        push @items, $str;
    }
    check_io( "50 strings", "T50", @items );
}

my $out = $folder->open_outstream('raw_vlongs');
$out->lu_write( 'W', 10000 );
$out->sclose;
my $in = $folder->open_instream('raw_vlongs');
my $raw;
$in->read_raw_vlong($raw);
my $correct = $folder->slurp_file('raw_vlongs');
is( $raw, $correct, "read_raw_vlong" );

$out = $folder->open_outstream('read_byteso');
$out->lu_write( 'a4', "cute" );
$out->sclose;
$in = $folder->open_instream('read_byteso');
my $buf = "buzz";
$in->read_byteso( $buf, 4, 3 );
is( $buf, "buzzcut", 'read_byteso' );
