use strict;
use warnings;

use Test::More tests => 8;

use KinoSearch::Store::FileDes;
use KinoSearch::Store::RAMFileDes;
use KinoSearch::Store::OutStream;
use KinoSearch::Store::InStream;

my ( $file_des, $outstream, $instream, $foo );

$file_des  = KinoSearch::Store::RAMFileDes->new("fake_file");
$outstream = KinoSearch::Store::OutStream->new($file_des);
$outstream->lu_write( 'a3', "foo" );
$outstream->sflush;
is( $file_des->contents->to_string, "foo", '$ramfile->contents' );

my $long_string = 'a' x 5000;
$outstream->lu_write( 'a5000', $long_string );
$outstream->sflush;

is( $file_des->contents->to_string,
    "foo$long_string", "store a string spread out over several buffers" );

$instream = KinoSearch::Store::InStream->new($file_des);
$foo      = $instream->lu_read('a3');
is( $foo, 'foo', "instream reads ramfile properly" );

my $long_dupe = $instream->lu_read('a5000');
is( $long_dupe, $long_string, "read string spread out over several buffers" );

eval { my $blah = $instream->lu_read('a3'); warn $blah };
like( $@, qr/EOF/, "reading past EOF throws an error" );

$file_des  = KinoSearch::Store::RAMFileDes->new("another_fake_file");
$outstream = KinoSearch::Store::OutStream->new($file_des);
my $BUF_SIZE  = KinoSearch::Store::FileDes::_BUF_SIZE();
my $rep_count = $BUF_SIZE - 1;
$outstream->lu_write( "a$rep_count", 'a' x $rep_count );
$outstream->lu_write( 'a3',          'foo' );
$outstream->sclose;
$instream = KinoSearch::Store::InStream->new($file_des);
$instream->lu_read("a$rep_count");
$foo = $instream->lu_read('a3');
is( $foo, 'foo', "read across buffer boundary " );

$file_des  = KinoSearch::Store::RAMFileDes->new("fake_files_galore");
$outstream = KinoSearch::Store::OutStream->new($file_des);
$outstream->lu_write( 'a1024', 'a' x 1024 );
$outstream->lu_write( 'a3',    'foo' );
$outstream->sclose;

$instream = KinoSearch::Store::InStream->new($file_des);
$instream->sseek(1024);
is( $instream->lu_read('a3'), 'foo', "InStream sseek" );

my $dupe = $instream->reopen( 'foo', 1023, 4 );
is( $dupe->lu_read('a4'), 'afoo', "reopened instream" );

