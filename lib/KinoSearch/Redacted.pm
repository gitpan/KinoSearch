use strict;
use warnings;

package KinoSearch::Redacted;
use Exporter;
BEGIN {
    our @ISA       = qw( Exporter );
    our @EXPORT_OK = qw( list );
}

# Return a partial list of KinoSearch classes which were once public but are
# now either deprecated, removed, or moved.

sub redacted {
    return qw(
        KinoSearch::Analysis::LCNormalizer
        KinoSearch::Analysis::Token
        KinoSearch::Analysis::TokenBatch
        KinoSearch::Index::Term
        KinoSearch::InvIndex
        KinoSearch::InvIndexer
        KinoSearch::QueryParser::QueryParser
        KinoSearch::Search::BooleanQuery
        KinoSearch::Search::QueryFilter
        KinoSearch::Search::SearchServer
        KinoSearch::Search::SearchClient
    );
}

# Hide additional stuff from PAUSE and search.cpan.org.
sub hidden {
    return qw(
        KinoSearch::Analysis::Inversion
        KinoSearch::FieldType::Int32Type
        KinoSearch::FieldType::Int64Type
        KinoSearch::FieldType::Float32Type
        KinoSearch::FieldType::Float64Type
        KinoSearch::Redacted
        KinoSearch::Test::TestUtils
        KinoSearch::Test::Util::TestCharBuf
        KinoSearch::Test::USConSchema
        KinoSearch::Util::Num
    );
}

1;
