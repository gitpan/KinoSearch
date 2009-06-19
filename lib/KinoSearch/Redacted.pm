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

sub list {
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

1;
