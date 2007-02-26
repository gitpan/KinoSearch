use strict;
use warnings;

use Test::More tests => 8;
use List::Util qw( shuffle );
use Storable qw( nfreeze thaw );

BEGIN { use_ok('KinoSearch::Index::Term') }

my $foo_term = KinoSearch::Index::Term->new( "f1", "foo" );
my $bar_term = KinoSearch::Index::Term->new( "f3", "bar" );

is( $foo_term->get_text,  'foo', "get_text should return correct val" );
is( $bar_term->get_field, "f3",  "get_field should return correct val" );

ok( !$foo_term->equals($bar_term), "equals() fails for unequal terms" );

my $another_foo = KinoSearch::Index::Term->new( "f1", "foo" );
ok( $foo_term->equals($another_foo),
    "equals() warks for same field/text combo" );

my $serialized = nfreeze($foo_term);
my $copy       = thaw($serialized);
ok( $foo_term->equals($copy), "serialization" );

my $evil_twin = $foo_term->clone;
ok( $foo_term->equals($evil_twin), "clone" );
is( $foo_term->to_string, $evil_twin->to_string,
    "clone checked via to_string" );

