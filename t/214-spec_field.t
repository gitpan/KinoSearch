use strict;
use warnings;

use KinoSearch::Test;

package PolyAnalyzerSpec;
use base qw( KinoSearch::Plan::FullTextType );
sub analyzer { KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' ) }

package MySchema;
use base qw( KinoSearch::Plan::Schema );

sub new {
    my $self      = shift->SUPER::new(@_);
    my $tokenizer = KinoSearch::Analysis::Tokenizer->new;
    my $polyanalyzer
        = KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );
    my $plain
        = KinoSearch::Plan::FullTextType->new( analyzer => $tokenizer, );
    my $polyanalyzed
        = KinoSearch::Plan::FullTextType->new( analyzer => $polyanalyzer );
    my $string_spec          = KinoSearch::Plan::StringType->new;
    my $unindexedbutanalyzed = KinoSearch::Plan::FullTextType->new(
        analyzer => $tokenizer,
        indexed  => 0,
    );
    my $unanalyzedunindexed
        = KinoSearch::Plan::StringType->new( indexed => 0, );
    $self->spec_field( name => 'analyzed',     type => $plain );
    $self->spec_field( name => 'polyanalyzed', type => $polyanalyzed );
    $self->spec_field( name => 'string',       type => $string_spec );
    $self->spec_field(
        name => 'unindexedbutanalyzed',
        type => $unindexedbutanalyzed
    );
    $self->spec_field(
        name => 'unanalyzedunindexed',
        type => $unanalyzedunindexed
    );
    return $self;
}

package main;
use Test::More tests => 10;

my $folder  = KinoSearch::Store::RAMFolder->new;
my $schema  = MySchema->new;
my $indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => $schema,
);

$indexer->add_doc( { $_ => 'United States' } ) for qw(
    analyzed
    polyanalyzed
    string
    unindexedbutanalyzed
    unanalyzedunindexed
);

$indexer->commit;

sub check {
    my ( $field, $query_text, $expected_num_hits ) = @_;
    my $query = KinoSearch::Search::TermQuery->new(
        field => $field,
        term  => $query_text,
    );
    my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );
    my $hits = $searcher->hits( query => $query );

    is( $hits->total_hits, $expected_num_hits, "$field correct num hits " );

    # Don't check the contents of the hit if there aren't any.
    return unless $expected_num_hits;

    my $hit = $hits->next;
    is( $hit->{$field}, 'United States', "$field correct doc returned" );
}

check( 'analyzed',             'States',        1 );
check( 'polyanalyzed',         'state',         1 );
check( 'string',               'United States', 1 );
check( 'unindexedbutanalyzed', 'state',         0 );
check( 'unindexedbutanalyzed', 'United States', 0 );
check( 'unanalyzedunindexed',  'state',         0 );
check( 'unanalyzedunindexed',  'United States', 0 );
