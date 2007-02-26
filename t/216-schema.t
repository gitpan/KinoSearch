use strict;
use warnings;

use Test::More tests => 8;
use KinoSearch::Analysis::Tokenizer;

package NoAnalyzerSchema::content;
use base qw( KinoSearch::Schema::FieldSpec );

package NoAnalyzerSchema;
use base qw( KinoSearch::Schema );

__PACKAGE__->init_fields(qw( content ));

package main;

eval { my $schema = NoAnalyzerSchema->new };
like( $@, qr/abstract/i, "Failing to define analyzer errors out" );

package BogusFieldSchema;
use base qw( KinoSearch::Schema );

eval { __PACKAGE__->init_fields(qw( bogus )); };
Test::More::like( $@, qr/FieldSpec/, "bogus field fails to load" );

package BogusKinoSchema::kino_bogus;
use base qw( KinoSearch::Schema::FieldSpec );

package BogusKinoSchema;
use base qw( KinoSearch::Schema );

eval { __PACKAGE__->init_fields(qw( kino_bogus )); };
Test::More::like( $@, qr/reserved/, "name starting with kino errors out" );

package ReservedSchema;
use base qw( KinoSearch::Schema );

for (qw( score boost doc_boost excerpt excerpts )) {
    eval { __PACKAGE__->init_fields($_); };
    Test::More::like( $@, qr/reserved/, "reserved name '$_' errors out" );
}

