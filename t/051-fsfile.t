use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 5;
use Carp;
use File::Spec::Functions qw( tmpdir catdir catfile );
use KinoSearch::Test::TestUtils qw( init_test_index_loc );

sub slurp_file {
    my $path = shift;
    open( my $fh, '<', $path ) or confess "Couldn't open '$path': $!";
    local $/;
    return <$fh>;
}

my $dir      = init_test_index_loc();
my $filename = 'hogus_bogus';
my $filepath = catfile( $dir, $filename );
my ( $outstream, $instream );
my $folder = KinoSearch::Store::FSFolder->new( path => $dir );
my $foo;

sub new_outstream {
    undef $outstream;
    unlink $filepath;
    return $folder->open_out($filename) || die "can't open $filename";
}

sub new_instream {
    undef $instream;
    return $folder->open_in($filename) || die "can't open $filename";
}

$outstream = new_outstream();
$outstream->print("foo");
$outstream->close;
$instream = new_instream();
undef $foo;
$instream->read_bytes( $foo, 3 );
is( $foo, "foo", "outstream writes, instream reads" );
$instream->close;

my $long_string = 'a' x 5000;
$outstream = new_outstream();
$outstream->print( 'foo', $long_string );
$outstream->close;
$instream = new_instream();
undef $foo;
$instream->read_bytes( $foo, 5003 );
is( $foo, "foo$long_string", "long string" );

eval { my $blah; $instream->read_bytes( $blah, 2 ) };
like( $@, qr/EOF/, "reading past EOF throws an error" );
undef $instream;

$outstream = new_outstream();
$outstream->print( 'a' x 1024 );
$outstream->print('foo');
$outstream->close;

$instream = new_instream();
$instream->seek(1024);
undef $foo;
$instream->read_bytes( $foo, 3 );
is( $foo, 'foo', "InStream seek" );

my $dupe = $instream->reopen( 'foo', 1023, 4 );
undef $foo;
$dupe->read_bytes( $foo, 4 );

is( $foo, 'afoo', "reopened instream" );

# Trigger destruction.
undef $folder;
