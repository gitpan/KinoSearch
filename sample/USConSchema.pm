use strict;
use warnings;

package USConSchema::title;
use base 'KinoSearch::Schema::FieldSpec';

package USConSchema::content;
use base 'KinoSearch::Schema::FieldSpec';

package USConSchema::url;
use base 'KinoSearch::Schema::FieldSpec';
sub indexed {0}

package USConSchema;
use base 'KinoSearch::Schema';
use KinoSearch::Analysis::PolyAnalyzer;

__PACKAGE__->init_fields(qw( title content url ));

sub analyzer {
    return KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );
}

1;
