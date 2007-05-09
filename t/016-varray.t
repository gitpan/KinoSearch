use strict;
use warnings;

use Test::More tests => 10;
use List::Util qw( shuffle );

use KinoSearch::Util::VArray;
use KinoSearch::Util::ByteBuf;

my ( $varray, @orig, @got );

$varray = KinoSearch::Util::VArray->new( capacity => 0 );
@orig   = 1 .. 10;

$varray->push( KinoSearch::Util::ByteBuf->new($_) ) for @orig;
is( $varray->get_size, 10, "get_size after pushing 10 elements" );

my $evil_twin = $varray->clone;
is( $evil_twin->get_size, 10, "get_size after clone" );
push @got, $_->to_string while defined( $_ = $evil_twin->shift );
is_deeply( \@got, \@orig, "clone" );
@got = ();

push @got, $_->to_string while defined( $_ = $varray->shift );
is_deeply( \@got, \@orig, "push and unshift" );
is( $varray->get_size, 0,
    "get_size after emptying KinoSearch::Util::VArray" );
@got = ();

$varray->unshift( KinoSearch::Util::ByteBuf->new($_) ) for @orig;
is( $varray->get_size, 10, "get_size after unshifting 10 elements" );
push @got, $_->to_string while defined( $_ = $varray->pop );
is_deeply( \@got, \@orig, "push and unshift" );
is( $varray->get_size, 0,
    "get_size after emptying KinoSearch::Util::VArray" );
@got = ();

$varray->push( KinoSearch::Util::ByteBuf->new($_) ) for @orig;
my $four = $varray->fetch(3)->to_string;
is( $four, 4, "fetch" );

$varray->store( 3, KinoSearch::Util::ByteBuf->new("foo") );
my $foo = $varray->fetch(3)->to_string;
is( $foo, "foo", "store" );
