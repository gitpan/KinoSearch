use strict;
use warnings;

use Test::More tests => 9;

package KinoSearch::TestClass;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # constructor params / members
    foo => 'correct',
);

BEGIN {
    __PACKAGE__->ready_get_set('foo');
}

sub die_an_abstract_death { shift->abstract_death }
sub die_a_todo_death      { shift->todo_death }

our $version = $KinoSearch::VERSION;

package MySubClass;
use base qw( Exporter KinoSearch::TestClass );

package main;

use Scalar::Util 'refaddr';

# These should NOT be accessed.
our %instance_vars = (
    foo => 'wrong',
    bar => 'wrong',
);

my $verify_version = defined $KinoSearch::TestClass::version;
is( $verify_version, 1,
          "Using this class should grant access to "
        . "package globals in the KinoSearch:: namespace" );

can_ok( 'KinoSearch::Util::Class', 'new' );

my $util_class_object = KinoSearch::Util::Class->new();
is( ref $util_class_object, 'KinoSearch::Util::Class', "constructor works" );

is( $util_class_object->hash_code,
    refaddr($util_class_object),
    "hash_code works"
);

my $test_obj = KinoSearch::TestClass->new;
is( $test_obj->{foo}, 'correct', "Inheritance works as expected" );

eval { $test_obj->die_an_abstract_death };
like( $@, qr/abstract/i,
    "abstract_death produces a meaningful error message" );

eval { $test_obj->die_a_todo_death };
like( $@, qr/todo/i, "todo_death produces a meaningful error message" );

my $subclassed_obj = MySubClass->new( foo => 'boo' );

is( $subclassed_obj->get_foo, "boo",
    "KinoSearch objects can be subclassed outside the KinoSearch hierarchy" );

$subclassed_obj->set_foo("hoo");
is( $subclassed_obj->get_foo, "hoo",
    "ready_get_set creates valid setter and getter" );
