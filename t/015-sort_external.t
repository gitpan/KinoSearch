use strict;
use warnings;

use Test::More tests => 15;
use List::Util qw( shuffle );
use KinoSearch::Test;
use bytes qw();

my ( $sortex, $cache, @orig, @sort_output );

$sortex = KinoSearch::Test::Util::BBSortEx->new( mem_thresh => 4 );
$sortex->feed( new_bytebuf('c') );
is( $sortex->cache_count, 1, "feed elem into cache" );

$sortex->feed( new_bytebuf('b') );
$sortex->feed( new_bytebuf('d') );
$sortex->sort_cache;
SKIP: {
    skip( "Restore when porting test to C", 1 );
    $cache = $sortex->_peek_cache;
    is_deeply( $cache, [qw( b c d )], "sort cache" );
}

$sortex->feed( new_bytebuf('a') );
is( $sortex->cache_count, 0,
    "cache flushed automatically when mem_thresh crossed" );
#is( $sortex->get_num_runs, 1, "run added" );

my @bytebufs = map { new_bytebuf($_) } qw( x y z );
my $run = KinoSearch::Test::Util::BBSortEx->new( external => \@bytebufs );
$sortex->add_run($run);
$sortex->flip;
@orig = qw( a b c d x y z );
while ( my $result = $sortex->fetch ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig, "Add_Run" );
@orig        = ();
@sort_output = ();

$sortex = KinoSearch::Test::Util::BBSortEx->new( mem_thresh => 4 );
$sortex->feed( new_bytebuf('c') );
$sortex->clear_cache;
is( $sortex->cache_count, 0, "Clear_Cache" );
$sortex->feed( new_bytebuf('b') );
$sortex->feed( new_bytebuf('a') );
$sortex->flush;
$sortex->flip;
@orig = qw( a b );
is( $sortex->peek, 'a', "Peek" );

while ( defined( my $result = $sortex->fetch ) ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig,
    "elements cleared via Clear_Cache truly cleared" );
@orig        = ();
@sort_output = ();

$sortex = KinoSearch::Test::Util::BBSortEx->new;
@orig   = ( 'a' .. 'z' );
$sortex->feed( new_bytebuf($_) ) for shuffle(@orig);
$sortex->flip;
while ( defined( my $result = $sortex->fetch ) ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig, "sort letters" );
@orig        = ();
@sort_output = ();

$sortex = KinoSearch::Test::Util::BBSortEx->new;
@orig   = qw( a a a b c d x x x x x x y y );
$sortex->feed( new_bytebuf($_) ) for shuffle(@orig);
$sortex->flip;
while ( defined( my $result = $sortex->fetch ) ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig, "sort repeated letters" );
@orig        = ();
@sort_output = ();

$sortex = KinoSearch::Test::Util::BBSortEx->new;
@orig = ( '', '', 'a' .. 'z' );
$sortex->feed( new_bytebuf($_) ) for shuffle(@orig);
$sortex->flip;
while ( defined( my $result = $sortex->fetch ) ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig, "sort letters and empty strings" );
@orig        = ();
@sort_output = ();

$sortex = KinoSearch::Test::Util::BBSortEx->new( mem_thresh => 30 );
@orig = 'a' .. 'z';
$sortex->feed( new_bytebuf($_) ) for shuffle(@orig);
$sortex->flip;
while ( defined( my $result = $sortex->fetch ) ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig, "... with an absurdly low mem_thresh" );
@orig        = ();
@sort_output = ();

$sortex = KinoSearch::Test::Util::BBSortEx->new( mem_thresh => 1 );
@orig = 'a' .. 'z';
$sortex->feed( new_bytebuf($_) ) for shuffle(@orig);
$sortex->flip;
while ( defined( my $result = $sortex->fetch ) ) {
    push @sort_output, $result;
}
is_deeply( \@sort_output, \@orig, "... with an even lower mem_thresh" );
@orig        = ();
@sort_output = ();

$sortex = KinoSearch::Test::Util::BBSortEx->new;
$sortex->flip;
@sort_output = $sortex->fetch;
is_deeply( \@sort_output, [undef], "Sorting nothing returns undef" );
@sort_output = ();

$sortex = KinoSearch::Test::Util::BBSortEx->new( mem_thresh => 5_000 );
@orig = map { pack( 'N', $_ ) } ( 0 .. 11_000 );
$sortex->feed( new_bytebuf($_) ) for shuffle(@orig);
$sortex->flip;
while ( defined( my $item = $sortex->fetch ) ) {
    push @sort_output, $item;
}
is_deeply( \@sort_output, \@orig, "Sorting packed integers..." );
@sort_output = ();

$sortex = KinoSearch::Test::Util::BBSortEx->new( mem_thresh => 15_000 );
@orig = ();
for my $iter ( 0 .. 1_000 ) {
    my $string = '';
    for my $string_len ( 0 .. int( rand(1200) ) ) {
        $string .= pack( 'C', int( rand(256) ) );
    }
    push @orig, $string;
}
$sortex->feed( new_bytebuf($_) ) for shuffle(@orig);
@orig = sort @orig;
$sortex->flip;
while ( defined( my $item = $sortex->fetch ) ) {
    push @sort_output, $item;
}
is_deeply( \@sort_output, \@orig, "Random binary strings of random length" );
@sort_output = ();

sub new_bytebuf { KinoSearch::Object::ByteBuf->new(shift) }

