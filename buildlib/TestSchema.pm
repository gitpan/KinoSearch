use strict;
use warnings;

package TestSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %FIELDS = ( content => 'KinoSearch::Schema::FieldSpec', );

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

1;
