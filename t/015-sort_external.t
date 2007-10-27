use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 9;
use File::Spec;
use List::Util qw( shuffle );
use KinoSearch::Util::SortExternal;
use KinoSearch::Index::SegInfos;
use KinoTestUtils qw( create_invindex );

my $invindex = create_invindex("foo");
my $seg_infos
    = KinoSearch::Index::SegInfos->new( schema => $invindex->get_schema );
$seg_infos->read_infos( folder => $invindex->get_folder );
my $seg_info = $seg_infos->get_info('_1');

my ( $sortex, @orig, @sort_output );

sub init_sortex {
    $sortex = KinoSearch::Util::BBSortEx->new(
        invindex => $invindex,
        seg_info => $seg_info,
        @_,
    );
}

init_sortex;
@orig = ( 'a' .. 'z' );
$sortex->feed_str($_) for shuffle(@orig);
$sortex->flip;
while ( my $result = $sortex->fetch ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig, "sort letters" );
@orig        = ();
@sort_output = ();

init_sortex;
$sortex->feed_str($_) for shuffle(@orig);
eval { $sortex->fetch; };
like( $@, qr/flip/i, "fetch before flip throws exception" );

init_sortex;
@orig = qw( a a a b c d x x x x x x y y );
$sortex->feed_str($_) for shuffle(@orig);
$sortex->flip;
while ( defined( my $result = $sortex->fetch ) ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig, "sort repeated letters" );
@orig        = ();
@sort_output = ();

init_sortex;
@orig = ( '', '', 'a' .. 'z' );
$sortex->feed_str($_) for shuffle(@orig);
$sortex->flip;
while ( defined( my $result = $sortex->fetch ) ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig, "sort letters and empty strings" );
@orig        = ();
@sort_output = ();

init_sortex( mem_thresh => 30 );
@orig = 'a' .. 'z';
$sortex->feed_str($_) for ( shuffle(@orig) );
$sortex->flip;
while ( my $result = $sortex->fetch ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig, "... with an absurdly low mem_thresh" );
@orig        = ();
@sort_output = ();

init_sortex( mem_thresh => 1 );
@orig = 'a' .. 'z';
$sortex->feed_str($_) for ( shuffle(@orig) );
$sortex->flip;
while ( my $result = $sortex->fetch ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig, "... with an even lower mem_thresh" );
@orig        = ();
@sort_output = ();

init_sortex;
$sortex->flip;
@sort_output = $sortex->fetch;
is_deeply( \@sort_output, [undef], "Sorting nothing returns undef" );
@sort_output = ();

init_sortex( mem_thresh => 20_000 );
@orig = map { pack( 'N', $_ ) } ( 0 .. 11_000 );
$sortex->feed_str( shuffle(@orig) );
$sortex->flip;
while ( defined( my $item = $sortex->fetch ) ) {
    push @sort_output, $item;
}
is_deeply( \@sort_output, \@orig, "Sorting packed integers..." );
@sort_output = ();

init_sortex( mem_thresh => 20_000 );
@orig = ();
for my $iter ( 0 .. 1_000 ) {
    my $string = '';
    for my $string_len ( 0 .. int( rand(1200) ) ) {
        $string .= pack( 'C', int( rand(256) ) );
    }
    push @orig, $string;
}
@orig = sort @orig;
$sortex->feed_str($_) for shuffle(@orig);
$sortex->flip;
while ( defined( my $item = $sortex->fetch ) ) {
    push @sort_output, $item;
}
is_deeply( \@sort_output, \@orig, "Random binary strings of random length" );
@sort_output = ();
