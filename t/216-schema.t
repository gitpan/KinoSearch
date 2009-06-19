use strict;
use warnings;

use lib 'buildlib';
use KinoSearch::Test;

package main;
use Test::More tests => 2;

my $schema;

SKIP: {
    skip( "constructor bailouts cause leaks", 1 ) if $ENV{KINO_VALGRIND};

    $schema = KinoSearch::Test::TestSchema->new;
    eval { $schema->spec_field( name => 'foo', type => 'NotAType' ) };
    Test::More::like( $@, qr/FieldType/, "bogus FieldType fails to load" );
}

$schema = KinoSearch::Test::TestSchema->new;
my $type = $schema->fetch_type('content');
$schema->spec_field( name => 'new_field', type => $type );
my $got = grep { $_ eq 'new_field' } @{ $schema->all_fields };
ok( $got, 'spec_field works' );

