use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 27;
use KinoSearch::Test::TestUtils qw( utf8_test_strings );
use KinoSearch::Util::StringHelper qw( utf8ify utf8_flag_off );
use bytes;
no bytes;

srand(2);

my $folder = KinoSearch::Store::RAMFolder->new;
my ( @nums, $packed, $template );

sub check_round_trip {
    my ( $filename, $type, $expected ) = @_;
    my $write_method = "write_$type";
    my $read_method  = "read_$type";
    my $outstream    = $folder->open_out($filename)
        or die "Can't open $filename";
    $outstream->$write_method($_) for @$expected;
    $outstream->close;
    my $instream = $folder->open_in($filename)
        or die "Can't open $filename";
    my @got;
    push @got, $instream->$read_method for @$expected;
    is_deeply( \@got, $expected, $filename );
}

sub check_round_trip_bytes {
    my ( $filename, $expected ) = @_;
    my $outstream = $folder->open_out($filename)
        or die "Can't open $filename";
    for (@$expected) {
        $outstream->write_c32( bytes::length($_) );
        $outstream->write_bytes($_);
    }
    $outstream->close;
    my $instream = $folder->open_in($filename)
        or die "Can't open $filename";
    my @got;
    for (@$expected) {
        my $buf;
        my $len = $instream->read_c32;
        $instream->read_bytes( $buf, $len );
        push @got, $buf;
    }
    is_deeply( \@got, $expected, $filename );
}

@nums = ( -128 .. 127 );
$packed = pack( 'c256', @nums );
check_round_trip( "signed byte", 'i8', \@nums );
is( $folder->slurp_file('signed byte'),
    $packed, "pack and write_i8 handle signed bytes identically" );

@nums = ( 0 .. 255 );
$packed = pack( 'C*', @nums );
check_round_trip( "unsigned byte", 'u8', \@nums );
is( $folder->slurp_file('unsigned byte'),
    $packed, "pack and write_u8 handle unsigned bytes identically" );

@nums = map { $_ * 1_000_000 + int( rand() * 1_000_000 ) } -1000 .. 1000;
push @nums, ( -1 * ( 2**31 ), 2**31 - 1 );
check_round_trip( "signed int", 'i32', \@nums );

@nums = map { $_ * 1_000_000 + int( rand() * 1_000_000 ) } 1000 .. 3000;
push @nums, ( 0, 1, 2**32 - 1 );
$packed = pack( 'N*', @nums );
check_round_trip( "unsigned int", 'u32', \@nums );
is( $folder->slurp_file('unsigned int'),
    $packed, "pack and write_u32 handle unsigned int32s identically" );

@nums = map { $_ * 2 } 0 .. 5;
check_round_trip( 'unsigned long small', 'u64', \@nums );

@nums = map { $_ * 2**31 } 0 .. 2000;
$_ += int( rand( 2**16 ) ) for @nums;
check_round_trip( 'unsigned long large', 'u64', \@nums );

@nums = ( 0 .. 127 );
check_round_trip( 'C32 small', 'c32', \@nums );

@nums = ( 128 .. 500 );
$packed = pack( 'w*', @nums );
check_round_trip( 'C32 medium', 'c32', \@nums );
is( $folder->slurp_file('C32 medium'),
    $packed, "C32 is equivalent to Perl's pack w" );

@nums = ( 0 .. 127 );
check_round_trip( 'C64 small', 'c64', \@nums );

@nums = ( 128 .. 500 );
$packed = pack( 'w*', @nums );
check_round_trip( 'C64 medium', 'c64', \@nums );
is( $folder->slurp_file('C64 medium'),
    $packed, "C64 is equivalent to Perl's pack w" );

@nums = map { $_ * 2**31 } 0 .. 2000;
$_ += int( rand( 2**16 ) ) for @nums;
check_round_trip( 'C64 large', 'c64', \@nums );

# rand (always?) has 64-bit precision, but we need 32-bit.
@nums = map {rand} 0 .. 100;
$packed = pack( 'f*', @nums );
@nums = unpack( 'f*', $packed );
check_round_trip( 'float', 'float', \@nums );

my @items;
for ( 0, 22, 300 ) {
    @items = ( 'a' x $_ );
    check_round_trip_bytes( "buf of length $_", \@items );
    check_round_trip( "string of length $_", 'string', \@items );
}

{
    my @chars = ( qw( a b c d 1 ), "\n", "\0", " ", " ", "\xf0\x9d\x84\x9e" );
    my @items = ();
    for ( 1 .. 50 ) {
        my $string_len = int( rand() * 5 );
        my $str        = '';
        $str .= $chars[ rand @chars ] for 1 .. $string_len;
        push @items, $str;
    }
    check_round_trip_bytes( "50 binary bufs", \@items );
}

my ( $smiley, $not_a_smiley, $frowny ) = utf8_test_strings();
check_round_trip( "unicode strings", "string", [ $smiley, $frowny ] );

my $latin = pack( 'a2Ca3', 'ma', 241, 'ana' );
check_round_trip( "latin", "string", [$latin] );
my $unibytes = $latin;
utf8ify($unibytes);
utf8_flag_off($unibytes);
my $slurped = $folder->slurp_file('latin');
substr( $slurped, 0, 1, "" );    # ditch c32 at head of string;
is( $slurped, $unibytes, "write_string upgrades to utf8" );

# Trigger destruction.
undef $folder;
