use strict;
use warnings;

use Test::More tests => 4;

BEGIN {
    use_ok('KinoSearch::Store::RAMFolder');
}

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

my $outstream = $folder->open_outstream("fake_file");
eval { $outstream->lu_write( 'u', 'foo' ); };
like( $@, qr/illegal character/i, "Illegal symbol in template caught" );

@items = qw( foo bar );
check_io( "leading and trailing whitespace", "    T    T   ", @items );

@items = ( qw( foo bar baz ), 0 .. 5 );
$template = "TT2Ti3Qb";
check_io( "Tightly packed template", $template, @items );
