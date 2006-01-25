use strict;
use warnings;

use Test::More tests => 8;

BEGIN { use_ok('KinoSearch::Util::Class') }

package FooTest;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars( foo => 'correct', );

sub die_an_abstract_death      { shift->abstract_death }
sub die_an_unimplemented_death { shift->unimplemented_death }
sub die_a_todo_death           { shift->todo_death }

our $version = $KinoSearch::VERSION;

package main;

# These should NOT be accessed.
our %instance_vars = (
    foo => 'wrong',
    bar => 'wrong',
);

my $verify_version = defined $FooTest::version;
is( $verify_version, 1,
          "Using this class should grant access to "
        . "package globals in the KinoSearch:: namespace" );

can_ok( 'KinoSearch::Util::Class', 'new' );

my $util_class_object = KinoSearch::Util::Class->new();
is( ref $util_class_object, 'KinoSearch::Util::Class', "constructor works." );

my $foo_test = FooTest->new;
is( $foo_test->{foo}, 'correct', "Inheritance works as expected" );

eval { $foo_test->die_an_abstract_death };
like( $@, qr/abstract/i,
    "abstract_death produces a meaningful error message" );

eval { $foo_test->die_a_todo_death };
like( $@, qr/todo/i, "todo_death produces a meaningful error message" );

eval { $foo_test->die_an_unimplemented_death };
like( $@, qr/unimplemented/i,
    "unimplemented_death produces a meaningful error message" );

