use strict;
use warnings;

package TestSchema::content;
use base qw( KinoSearch::Schema::FieldSpec );

package TestSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

__PACKAGE__->init_fields(qw( content ));

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

1;
