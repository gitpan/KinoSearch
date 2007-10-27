use strict;
use warnings;
use lib 'buildlib';

package NoFieldsSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package NoAnalyzerSchema;
use base qw( KinoSearch::Schema );

our %fields = ( content => 'text' );

package main;
use Test::More tests => 14;
use TestSchema;

my $schema;

eval { $schema = NoFieldsSchema->new };
like( $@, qr/fields/i, "Failing to define \%fields errors out" );

eval { $schema = NoAnalyzerSchema->new };
like( $@, qr/abstract/i, "Failing to define analyzer errors out" );

$schema = TestSchema->new;
$schema->add_field( new_field => 'text' );
my $got = grep { $_ eq 'new_field' } $schema->all_fields;
ok( $got, 'add_field works' );
is( $schema->field_num('content'),   0, "field_num" );
is( $schema->field_num('new_field'), 1, "new field_num" );

$schema = TestSchema->new;
eval { $schema->add_field( foo => 'NotAFieldSpec' ) };
Test::More::like( $@, qr/NotAFieldSpec/, "bogus FieldSpec fails to load" );

$schema = TestSchema->new;
eval { $schema->add_field( kInObogus => 'text' ) };
Test::More::like( $@, qr/reserved/, "name starting with kino errors out" );

$schema = TestSchema->new;
for (qw( score boost doc_boost excerpt excerpts )) {
    eval { $schema->add_field( $_ => 'text' ) };
    Test::More::like( $@, qr/reserved/, "reserved name '$_' errors out" );
}

$schema = TestSchema->new;
eval { $schema->add_field( foo => 'texty' ) };
Test::More::like( $@, qr/lower/, "lower case name reserved" );

$schema = TestSchema->new;
eval { $schema->add_field( foo => 'KinoSearch::Schema::FieldSpec' ) };
Test::More::ok( !$@, "KinoSearch::Schema::FieldSpec still works" );
