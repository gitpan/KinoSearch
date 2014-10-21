use strict;
use warnings;
use lib 'buildlib';

package MySchema;
use base qw( KinoSearch::Plan::Schema );
use KinoSearch::Analysis::Tokenizer;

sub new {
    my $self = shift->SUPER::new(@_);
    my $analyzer = KinoSearch::Analysis::Tokenizer->new( pattern => '\S+' );
    my $type = KinoSearch::Plan::FullTextType->new( analyzer => $analyzer, );
    $self->spec_field( name => 'content', type => $type );
    return $self;
}

package main;
use Test::More tests => 14;
use KinoSearch::Test;
use KinoSearch::Test::TestUtils qw( utf8_test_strings );

my ( $smiley, $not_a_smiley, $frowny ) = utf8_test_strings();

my $turd = pack( 'C*', 254, 254 );
my $polished_turd = $turd;
utf8::upgrade($polished_turd);

is( $turd, $polished_turd, "verify encoding acrobatics" );

my $folder  = KinoSearch::Store::RAMFolder->new;
my $schema  = MySchema->new;
my $indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => $schema,
);

$indexer->add_doc( { content => $smiley } );
$indexer->add_doc( { content => $not_a_smiley } );
$indexer->add_doc( { content => $turd } );
$indexer->commit;

my $qparser = KinoSearch::Search::QueryParser->new( schema => MySchema->new );
my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );

my $hits = $searcher->hits( query => $qparser->parse($smiley) );
is( $hits->total_hits, 1 );
is( $hits->next->{content},
    $smiley, "Indexer and QueryParser handle UTF-8 source correctly" );

$hits = $searcher->hits( query => $qparser->parse($frowny) );
is( $hits->total_hits, 1 );
is( $hits->next->{content}, $frowny, "Indexer upgrades non-UTF-8 correctly" );

$hits = $searcher->hits( query => $qparser->parse($not_a_smiley) );
is( $hits->total_hits, 1 );
is( $hits->next->{content},
    $not_a_smiley, "QueryParser upgrades non-UTF-8 correctly" );

my $term_query = KinoSearch::Search::TermQuery->new(
    field => 'content',
    term  => $not_a_smiley,
);
$hits = $searcher->hits( query => $term_query );
is( $hits->total_hits, 1 );
is( $hits->next->{content},
    $not_a_smiley, "TermQuery upgrades non-UTF-8 correctly" );

$term_query = KinoSearch::Search::TermQuery->new(
    field => 'content',
    term  => $smiley,
);

$hits = $searcher->hits( query => $term_query );
is( $hits->total_hits, 1 );
is( $hits->next->{content}, $smiley, "TermQuery handles UTF-8 correctly" );

undef $indexer;
$indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => $schema,
);
$indexer->delete_by_term( field => 'content', term => $smiley );
$indexer->commit;
$searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );

$hits = $searcher->hits( query => $smiley );
is( $hits->total_hits, 0, "delete_by_term handles UTF-8 correctly" );

$hits = $searcher->hits( query => $frowny );
is( $hits->total_hits, 1, "delete_by_term handles UTF-8 correctly" );

undef $indexer;
$indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => $schema,
);
$indexer->delete_by_term( field => 'content', term => $not_a_smiley );
$indexer->commit;
$searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );

$hits = $searcher->hits( query => $frowny );
is( $hits->total_hits, 0, "delete_by_term upgrades non-UTF-8 correctly" );
