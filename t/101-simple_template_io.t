use strict;
use warnings;

use Test::More tests => 16;

use KinoSearch::Store::RAMFolder;

srand(2);

my $folder = KinoSearch::Store::RAMFolder->new;
my ( @nums, $packed, $template );

sub check_io {
    my ( $filename, $tpt ) = ( shift, shift );
    my $outstream = $folder->open_outstream($filename);
    $outstream->lu_write( $tpt, @_ );
    $outstream->sclose;
    my $instream = $folder->open_instream($filename);
    my @got      = $instream->lu_read($tpt);
    is_deeply( \@got, \@_, $filename );
}

@nums = ( -128 .. 127 );
$packed = pack( 'c256', @nums );
check_io( "signed byte", 'b256', @nums );
is( $folder->slurp_file('signed byte'),
    $packed, "pack and lu_write handle signed bytes identically" );

@nums = ( 0 .. 255 );
$packed = pack( 'C*', @nums );
check_io( "unsigned byte", 'B256', @nums );
is( $folder->slurp_file('unsigned byte'),
    $packed, "pack and lu_write handle unsigned bytes identically" );

@nums = map { $_ * 1_000_000 + int( rand() * 1_000_000 ) } -1000 .. 1000;
push @nums, ( -1 * ( 2**31 ), 2**31 - 1 );
check_io( "signed int", 'i' . scalar @nums, @nums );

@nums = map { $_ * 1_000_000 + int( rand() * 1_000_000 ) } 1000 .. 3000;
push @nums, ( 0, 1, 2**32 - 1 );
$packed = pack( 'N*', @nums );
check_io( "unsigned int", 'I' . scalar @nums, @nums );
is( $folder->slurp_file('unsigned int'),
    $packed, "pack and lu_write handle unsigned int32s identically" );

@nums = map { $_ * 2 } 0 .. 5;
check_io( 'unsigned long small', 'Q' . scalar @nums, @nums );

@nums = map { $_ * 2**31 } 0 .. 2000;
$_ += int( rand( 2**16 ) ) for @nums;
check_io( 'unsigned long large', 'Q' . scalar @nums, @nums );

@nums = ( 0 .. 127 );
check_io( 'VInt small', 'V' . scalar @nums, @nums );

@nums = ( 128 .. 500 );
$packed = pack( 'w*', @nums );
check_io( 'VInt medium', 'V' . scalar @nums, @nums );
is( $folder->slurp_file('VInt medium'),
    $packed, "VInt is equivalent to Perl's pack w" );

@nums = ( 0 .. 127 );
check_io( 'VLong small', 'W' . scalar @nums, @nums );

@nums = ( 128 .. 500 );
$packed = pack( 'w*', @nums );
check_io( 'VLong medium', 'W' . scalar @nums, @nums );
is( $folder->slurp_file('VLong medium'),
    $packed, "VLong is equivalent to Perl's pack w" );

@nums = map { $_ * 2**31 } 0 .. 2000;
$_ += int( rand( 2**16 ) ) for @nums;
check_io( 'VLong large', 'W' . scalar @nums, @nums );
