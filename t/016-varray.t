use strict;
use warnings;

use Test::More tests => 21;
use List::Util qw( shuffle );
use Storable qw( nfreeze thaw );
use KinoSearch::Test;

my ( $varray, @orig, @got );

$varray = KinoSearch::Util::VArray->new( capacity => 0 );
@orig = 1 .. 10;

$varray->push( KinoSearch::Util::CharBuf->new($_) ) for @orig;
is( $varray->get_size, 10, "get_size after pushing 10 elements" );

my $evil_twin = $varray->shallow_copy;
is( $evil_twin->get_size, 10, "get_size after shallow_copy" );
push @got, $_->to_string while defined( $_ = $evil_twin->shift );
is_deeply( \@got, \@orig, "shallow_copy" );
@got = ();

push @got, $_->to_string while defined( $_ = $varray->shift );
is_deeply( \@got, \@orig, "push and unshift" );
is( $varray->get_size, 0,
    "get_size after emptying KinoSearch::Util::VArray" );
@got = ();

$varray->unshift( KinoSearch::Util::CharBuf->new($_) ) for @orig;
is( $varray->get_size, 10, "get_size after unshifting 10 elements" );
push @got, $_->to_string while defined( $_ = $varray->pop );
is_deeply( \@got, \@orig, "push and unshift" );
is( $varray->get_size, 0,
    "get_size after emptying KinoSearch::Util::VArray" );
@got = ();

$varray->push( KinoSearch::Util::CharBuf->new($_) ) for @orig;
my $four = $varray->fetch(3)->to_string;
is( $four, 4, "fetch" );

$varray->store( 3, KinoSearch::Util::CharBuf->new("foo") );
my $foo = $varray->fetch(3)->to_string;
is( $foo, "foo", "store" );

$varray = KinoSearch::Util::VArray->new( capacity => 0 );
$varray->push( KinoSearch::Util::CharBuf->new($_) ) for @orig;
$varray->push_varray($varray);
push @got, $_->to_string while defined( $_ = $varray->shift );
is_deeply( \@got, [ @orig, @orig ], "push_varray" );

$varray = KinoSearch::Util::VArray->new( capacity => 5 );
$varray->push( KinoSearch::Util::CharBuf->new($_) ) for 1 .. 5;
$varray->splice( offset => 7, length => 1 );
is_deeply( $varray->to_perl, [ 1 .. 5 ], "splice outside of range is no-op" );
$varray->splice( offset => 2, length => 2 );
is_deeply( $varray->to_perl, [ 1, 2, 5 ], "splice multiple elems" );
$varray->splice( offset => 2, length => 2 );
is_deeply( $varray->to_perl, [ 1, 2 ], "splicing too many elems truncates" );
$varray->splice( offset => 0, length => 1 );
is_deeply( $varray->to_perl, [2], "splice first elem" );

$varray = KinoSearch::Util::VArray->new( capacity => 5 );
$varray->push( KinoSearch::Util::CharBuf->new($_) ) for 1 .. 5;
$varray->delete(2);
$varray->delete(4);
is_deeply( $varray->to_perl, [ 1, 2, undef, 4, undef ], "delete" );

$varray = KinoSearch::Util::VArray->new( capacity => 5 );
$varray->push( KinoSearch::Util::CharBuf->new($_) ) for 1 .. 5;
$varray->delete(3);
my $frozen = nfreeze($varray);
my $thawed = thaw($frozen);
is_deeply( $thawed->to_perl, $varray->to_perl, "freeze/thaw" );

my $ram_file  = KinoSearch::Store::RAMFileDes->new;
my $outstream = KinoSearch::Store::OutStream->new($ram_file);
$varray->serialize($outstream);
$outstream->close;
my $instream     = KinoSearch::Store::InStream->new($ram_file);
my $deserialized = $varray->deserialize($instream);
is_deeply( $varray->to_perl, $deserialized->to_perl,
    "serialize/deserialize" );

$evil_twin = $varray->_clone;
is_deeply( $evil_twin->to_perl, $varray->to_perl, "clone" );

$varray = KinoSearch::Util::VArray->new( capacity => 3 );
$varray->push( KinoSearch::Util::CharBuf->new($_) ) for 1 .. 3;
$varray->resize(4);
is_deeply( $varray->to_perl, [ 1, 2, 3, undef ], "resize up" );
$varray->resize(2);
is_deeply( $varray->to_perl, [ 1, 2 ], "resize down" );

