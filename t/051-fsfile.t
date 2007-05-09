use strict;
use warnings;

use Test::More tests => 6;
use Carp;
use File::Spec::Functions qw( tmpdir catdir catfile );
use KinoSearch::Store::FSFileDes;
use KinoSearch::Store::OutStream;
use KinoSearch::Store::InStream;
use KinoSearch::Store::FSFolder;

sub slurp_file {
    my $path = shift;
    open( my $fh, '<', $path ) or confess "Couldn't open '$path': $!";
    local $/;
    return <$fh>;
}

my $dir = catdir( tmpdir(), 'bogus_invindex' );
if ( !-d $dir ) {
    mkdir $dir or die "Couldn't mkdir '$dir': $!";
}
my $filename = 'hogus_bogus';
my $filepath = catfile( $dir, $filename );
my ( $outstream, $instream );
my $folder = KinoSearch::Store::FSFolder->new( path => $dir );

sub new_outstream {
    return $folder->open_outstream($filename);
}

sub new_instream {
    return $folder->open_instream($filename);
}

$outstream = new_outstream();
$outstream->lu_write( 'a3', "foo" );
$outstream->sclose;
$instream = new_instream();
is( $instream->lu_read('a3'), "foo", "outstream writes, instream reads" );
$instream->sclose;

my $long_string = 'a' x 5000;
$outstream = new_outstream();
$outstream->lu_write( 'a3',    'foo' );
$outstream->lu_write( 'a5000', $long_string );
$outstream->sclose;
$instream = new_instream();
is( $instream->lu_read('a5003'), "foo$long_string", "long string" );

eval { my $blah = $instream->lu_read('bb') };
like( $@, qr/EOF/, "reading past EOF throws an error" );

$outstream = new_outstream();
$outstream->lu_write( 'a1024', 'a' x 1024 );
$outstream->lu_write( 'a3',    'foo' );
$outstream->sseek(0);
$outstream->lu_write( 'a3', 'foo' );
$outstream->sclose;

$instream = new_instream();
is( $instream->lu_read('a3'), 'foo', "OutStream write after sseek" );
$instream->sseek(1024);
is( $instream->lu_read('a3'), 'foo', "InStream sseek" );

my $dupe = $instream->reopen( 'foo', 1023, 4 );
is( $dupe->lu_read('a4'), 'afoo', "reopened instream" );
