use strict;
use warnings;

package USConSchema::UnIndexedField;
use base 'KinoSearch::Schema::FieldSpec';
sub indexed {0}

package USConSchema;
use base 'KinoSearch::Schema';
use KinoSearch::Analysis::PolyAnalyzer;

our %FIELDS = (
    title   => 'KinoSearch::Schema::FieldSpec',
    content => 'KinoSearch::Schema::FieldSpec',
    url     => 'USConSchema::UnIndexedField',
);

sub analyzer {
    return KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );
}

1;
