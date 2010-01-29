use strict;
use warnings;
use lib 'buildlib';

package MatchSchema::MatchOnly;
use base qw( KinoSearch::FieldType::FullTextType );
use KinoSearch::Posting::MatchPosting;

sub make_posting {
    if ( @_ == 2 ) {
        return KinoSearch::Posting::MatchPosting->new( similarity => $_[1] );
    }
    else {
        shift;
        return KinoSearch::Posting::MatchPosting->new(@_);
    }
}

package MatchSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

sub new {
    my $self = shift->SUPER::new(@_);
    my $type = MatchSchema::MatchOnly->new(
        analyzer => KinoSearch::Analysis::Tokenizer->new );
    $self->spec_field( name => 'content', type => $type );
    return $self;
}

package main;

use KinoSearch::Test::TestUtils qw( get_uscon_docs );
use Test::More tests => 6;

my $uscon_docs = get_uscon_docs();
my $match_folder = make_index( MatchSchema->new, $uscon_docs );
my $score_folder
    = make_index( KinoSearch::Test::TestSchema->new, $uscon_docs );

my $match_searcher = KinoSearch::Searcher->new( index => $match_folder );
my $score_searcher = KinoSearch::Searcher->new( index => $score_folder );

for (qw( land of the free )) {
    my $match_got = hit_ids_array( $match_searcher, $_ );
    my $score_got = hit_ids_array( $score_searcher, $_ );
    is_deeply( $match_got, $score_got, "same hits for '$_'" );
}

my $qstring          = '"the legislature"';
my $should_have_hits = hit_ids_array( $score_searcher, $qstring );
my $should_be_empty  = hit_ids_array( $match_searcher, $qstring );
ok( scalar @$should_have_hits, "successfully scored phrase $qstring" );
ok( !scalar @$should_be_empty, "no hits matched for phrase $qstring" );

sub make_index {
    my ( $schema, $docs ) = @_;
    my $folder  = KinoSearch::Store::RAMFolder->new;
    my $indexer = KinoSearch::Indexer->new(
        schema => $schema,
        index  => $folder,
    );
    $indexer->add_doc( { content => $_->{bodytext} } ) for values %$docs;
    $indexer->commit;
    return $folder;
}

sub hit_ids_array {
    my ( $searcher, $query_string ) = @_;
    my $query = $searcher->glean_query($query_string);

    my $bit_vec = KinoSearch::Object::BitVector->new(
        capacity => $searcher->doc_max + 1 );
    my $bit_collector = KinoSearch::Search::HitCollector::BitCollector->new(
        bit_vector => $bit_vec, );
    $searcher->collect( query => $query, collector => $bit_collector );
    return $bit_vec->to_array->to_arrayref;
}

