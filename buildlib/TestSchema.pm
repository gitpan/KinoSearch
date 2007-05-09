use strict;
use warnings;

package TestSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

our %fields = ( content => 'KinoSearch::Schema::FieldSpec', );

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

# Expose problems faced by much larger indexes by using absurdly low values
# for index_interval and skip_interval.
sub index_interval {5}
sub skip_interval  {3}

1;
