use strict;
use warnings;

use lib 't';
use Test::More tests => 6;
use File::Spec;
use List::Util qw( shuffle );

BEGIN {
    use_ok("KinoSearch::Util::SortExternal");
}
use KinoSearchTestInvIndex qw( create_invindex );

my $invindex = create_invindex();

my ( $sortex, @sort_output );

sub init_sortex {
    $sortex = KinoSearch::Util::SortExternal->new(
        invindex => $invindex,
        seg_name => '_1',
        @_,
    );
}

init_sortex;
$sortex->feed($_) for ( shuffle 'a' .. 'z' );
$sortex->sort_all;
while ( my $result = $sortex->fetch ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, [ 'a' .. 'z' ], "sort letters" );
@sort_output = ();

init_sortex( mem_threshold => 30 );
init_sortex;
$sortex->feed($_) for ( shuffle 'a' .. 'z' );
$sortex->sort_all;
while ( my $result = $sortex->fetch ) {
    push @sort_output, $result;
}
is_deeply(
    \@sort_output,
    [ 'a' .. 'z' ],
    "... with an absurdly low mem_threshold"
);
@sort_output = ();

init_sortex;
$sortex->sort_all;
@sort_output = $sortex->fetch;
is_deeply( \@sort_output, [undef], "Sorting nothing returns undef" );
@sort_output = ();

init_sortex( mem_threshold => 20_000 );
my @orig = map { pack( 'N', $_ ) } ( 0 .. 11_000 );
unshift @orig, '';
$sortex->feed( shuffle(@orig) );
$sortex->sort_all;
while ( defined( my $item = $sortex->fetch ) ) {
    push @sort_output, $item;
}
is_deeply( \@sort_output, \@orig, "Sorting packed integers..." );
@sort_output = ();

init_sortex( mem_threshold => 20_000 );
@orig = ();
for my $iter ( 0 .. 1_000 ) {
    my $string = '';
    for my $string_len ( 0 .. int( rand(1200) ) ) {
        $string .= pack( 'C', int( rand(256) ) );
    }
    push @orig, $string;
}
@orig = sort @orig;
$sortex->feed($_) for shuffle(@orig);
$sortex->sort_all;
while ( defined( my $item = $sortex->fetch ) ) {
    push @sort_output, $item;
}
is_deeply( \@sort_output, \@orig, "Random binary strings of random length" );
@sort_output = ();
