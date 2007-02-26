use strict;
use warnings;

use Test::More tests => 16;
use List::Util qw( shuffle );

BEGIN { use_ok('KinoSearch::Util::Hash') }
use KinoSearch::Util::ByteBuf;

my ( $hash, @orig, @got );
my ( %source, $dest_ref );

sub build_perl_hashref {
    my $kino_hash = shift;
    my %perl_hash;
    $hash->iter_init;
    while ( my ( $k, $v ) = $kino_hash->iter_next ) {
        $perl_hash{ $k->to_string } = $v->to_string;
    }
    return \%perl_hash;
}

# convenient alias
sub new_bb { KinoSearch::Util::ByteBuf->new( $_[0] ) }

$hash = KinoSearch::Util::Hash->new( capacity => 1 );

@orig = 1 .. 100;
$hash->store( $_, new_bb($_) ) for @orig;
$source{$_} = $_ for @orig;
push @got, $hash->fetch($_) for 1 .. 100;
@got = map { $_->to_string } @got;
is_deeply( \@got, \@orig, "Basic store and fetch" );

is( $hash->get_size, 100, "size incremented properly" );

$hash->store( "40", new_bb("new value") );
is( $hash->fetch("40")->to_string,
    "new value", "store obliterates existing value" );
is( $hash->get_size, 100, "size unaffected after replacement of a val" );
$source{40} = "new value";
$dest_ref = build_perl_hashref($hash);
is_deeply( $dest_ref, \%source, "overwriting doesn't affect other members" );

# delete
is( $hash->delete("40"), 1, "delete returns true when key exists" );
is( $hash->get_size, 99, "delete decrements size when successful" );
$dest_ref = build_perl_hashref($hash);
delete $source{40};
is_deeply( $dest_ref, \%source,
    "successful deleting doesn't affect other members" );

ok( !$hash->delete("40"), "delete returns false when key doesn't exist" );
is( $hash->get_size, 99, "delete doesn't decrement size when unsuccessful" );
$dest_ref = build_perl_hashref($hash);
is_deeply( $dest_ref, \%source,
    "unsuccessful deleting doesn't affect other members" );

# clear
$hash->clear;
is( $hash->fetch("2"), undef, "clear" );
is( $hash->get_size, 0, "size is 0 after clear" );

# iter_init, iter_next
%source = ();
$hash = KinoSearch::Util::Hash->new( capacity => 1 );
for ( 1 .. 10 ) {
    $source{$_} = $_;
    $hash->store( $_, new_bb($_) );
}
$dest_ref = build_perl_hashref($hash);
is_deeply( \%source, $dest_ref, "iteration" );

# stress test
%source = ();
$hash = KinoSearch::Util::Hash->new( capacity => 1 );
for my $iter ( 1 .. 500 ) {
    my $string = '';
    for my $string_len ( 0 .. int( rand(1200) ) ) {
        $string .= pack( 'C', int( rand(256) ) );
    }
    $source{$string} = "value: $string";
}
while ( my ( $k, $v ) = each %source ) {
    $hash->store( $k, new_bb($v) );
}
while ( my ( $k, $v ) = each %source ) {
    $hash->store( $k, new_bb($v) );    # overwrite every pair for good measure
}

$dest_ref = build_perl_hashref($hash);
is_deeply( \%source, $dest_ref, "random binary strings" );

