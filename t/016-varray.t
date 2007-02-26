use strict;
use warnings;

use Test::More tests => 9;
use List::Util qw( shuffle );

BEGIN { use_ok('KinoSearch::Util::VArray') }
use KinoSearch::Util::ByteBuf;

sub new_bb { KinoSearch::Util::ByteBuf->new( $_[0] ) }

my ( $varray, @orig, @got );

$varray = KinoSearch::Util::VArray->new( capacity => 0 );
@orig   = 1 .. 10;

$varray->push( new_bb($_) ) for @orig;
is( $varray->get_size, 10, "get_size after pushing 10 elements" );
push @got, $_->to_string while defined( $_ = $varray->shift );
is_deeply( \@got, \@orig, "push and unshift" );
is( $varray->get_size, 0, "get_size after emptying VArray" );
@got = ();

$varray->unshift( new_bb($_) ) for @orig;
is( $varray->get_size, 10, "get_size after unshifting 10 elements" );
push @got, $_->to_string while defined( $_ = $varray->pop );
is_deeply( \@got, \@orig, "push and unshift" );
is( $varray->get_size, 0, "get_size after emptying VArray" );
@got = ();

$varray->push( new_bb($_) ) for @orig;
my $four = $varray->fetch(3)->to_string;
is( $four, 4, "fetch" );

$varray->store( 3, new_bb("foo") );
my $foo = $varray->fetch(3)->to_string;
is( $foo, "foo", "store" );

