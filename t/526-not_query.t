use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 61;
use Storable qw( freeze thaw );
use KinoSearch::Test::TestUtils qw( create_index );
use KSx::Search::MockScorer;

my @got;

my $folder = create_index( 'a' .. 'z' );

my $b_query = KinoSearch::Search::TermQuery->new(
    field => 'content',
    term  => 'b'
);
my $c_query = KinoSearch::Search::TermQuery->new(
    field => 'content',
    term  => 'c'
);
my $not_b_query
    = KinoSearch::Search::NOTQuery->new( negated_query => $b_query );
my $not_c_query
    = KinoSearch::Search::NOTQuery->new( negated_query => $c_query );

is( $not_b_query->to_string, "-content:b", "to_string" );

my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );
my $reader   = $searcher->get_reader;
my $hits     = $searcher->hits(
    query      => $not_b_query,
    num_wanted => 100
);
is( $hits->total_hits, 25, "not b" );
@got = ();
while ( my $hit = $hits->next ) {
    push @got, $hit->{content};
}
is_deeply( \@got, [ 'a', 'c' .. 'z' ], "correct hits" );

my $frozen = freeze($not_b_query);
my $thawed = thaw($frozen);
ok( $not_b_query->equals($thawed), "equals" );
$thawed->set_boost(10);
ok( !$not_b_query->equals($thawed), '!equals (boost)' );
ok( !$not_b_query->equals($not_c_query),
    "!equals (different negated query)" );

my $compiler = $not_b_query->make_compiler( searcher => $searcher );
$frozen = freeze($compiler);
$thawed = thaw($frozen);
ok( $thawed->equals($compiler), 'freeze/thaw compiler' );

# Air out NOTScorer with random patterns.
for my $num_negated ( 1 .. 26 ) {
    my @source_ids = ( 1 .. 26 );
    my @mock_ids;
    for ( 1 .. $num_negated ) {
        my $tick = int( rand @source_ids );
        push @mock_ids, splice( @source_ids, $tick, 1 );
    }
    @mock_ids = sort { $a <=> $b } @mock_ids;
    my $mock_scorer = KSx::Search::MockScorer->new(
        doc_ids => \@mock_ids,
        scores  => [ (1) x scalar @mock_ids ],
    );
    my $not_scorer = KinoSearch::Search::NOTScorer->new(
        doc_max         => $reader->doc_max,
        negated_matcher => $mock_scorer,
    );
    my $bit_vec = KinoSearch::Object::BitVector->new( capacity => 30 );
    my $collector = KinoSearch::Search::Collector::BitCollector->new(
        bit_vector => $bit_vec, );
    $not_scorer->collect( collector => $collector );
    my $got = $bit_vec->to_arrayref;
    is( scalar @$got, scalar @source_ids, "got all docs ($num_negated)" );
    is_deeply( $got, \@source_ids, "correct retrieval ($num_negated)" );
}

my $indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => KinoSearch::Test::TestSchema->new,
);
$indexer->delete_by_term( field => 'content', term => 'b' );
$indexer->commit;

@got      = ();
$searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );
$hits     = $searcher->hits( query => $not_b_query, num_wanted => 100 );
is( $hits->total_hits, 25, "still correct after deletion" );
while ( my $hit = $hits->next ) {
    push @got, $hit->{content};
}
is_deeply( \@got, [ 'a', 'c' .. 'z' ], "correct hits after deletion" );
