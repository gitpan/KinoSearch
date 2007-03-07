use strict;
use warnings;
use lib 'buildlib';

use KinoSearch::Analysis::Tokenizer;

package NoFieldsSchema;
use base qw( KinoSearch::Schema );

sub analyzer { KinoSearch::Analysis::Tokenizer->new } 

package NoAnalyzerSchema;
use base qw( KinoSearch::Schema );

our %FIELDS = ( content => 'KinoSearch::Schema::FieldSpec' );

package main;
use Test::More tests => 10;
use TestSchema;

my $schema;

eval { $schema = NoFieldsSchema->new };
like( $@, qr/FIELDS/i, "Failing to define \%FIELDS errors out" );

eval { $schema = NoAnalyzerSchema->new };
like( $@, qr/abstract/i, "Failing to define analyzer errors out" );

$schema = TestSchema->new;
$schema->add_field( new_field => 'KinoSearch::Schema::FieldSpec' );
my $got = grep { $_ eq 'new_field' } $schema->all_fields;
ok( $got, 'add_field works' );

$schema = TestSchema->new;
eval { $schema->add_field( foo => 'NotAFieldSpec' ) };
Test::More::like( $@, qr/FieldSpec/, "bogus FieldSpec fails to load" );

$schema = TestSchema->new;
eval { $schema->add_field( kInObogus => 'KinoSearch::Schema::FieldSpec' ) };
Test::More::like( $@, qr/reserved/, "name starting with kino errors out" );

$schema = TestSchema->new;
for (qw( score boost doc_boost excerpt excerpts )) {
    eval { $schema->add_field( $_ => 'KinoSearch::Schema::FieldSpec' ) };
    Test::More::like( $@, qr/reserved/, "reserved name '$_' errors out" );
}

