use strict;
use warnings;

package USConSchema::UnIndexedField;
use base 'KinoSearch::FieldSpec::text';
sub indexed {0}

package USConSchema;
use base 'KinoSearch::Schema';
use KinoSearch::Analysis::PolyAnalyzer;

our %fields = (
    title   => 'text',
    content => 'text',
    url     => 'USConSchema::UnIndexedField',
);

sub analyzer {
    return KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );
}

1;
