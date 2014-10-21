use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 7;
use Storable qw( freeze thaw );
use KinoSearch::Test::TestUtils qw( create_index );

my $folder = create_index( 'a' .. 'z' );
my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );

my $match_all_query = KinoSearch::Search::MatchAllQuery->new;
is( $match_all_query->to_string, "[MATCHALL]", "to_string" );

my $hits = $searcher->hits( query => $match_all_query );
is( $hits->total_hits, 26, "match all" );

my $indexer = KinoSearch::Index::Indexer->new(
    index  => $folder,
    schema => KinoSearch::Test::TestSchema->new,
);
$indexer->delete_by_term( field => 'content', term => 'b' );
$indexer->commit;

$searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );
$hits = $searcher->hits( query => $match_all_query, num_wanted => 100 );
is( $hits->total_hits, 25, "match all minus a deletion" );
my @got;
while ( my $hit = $hits->next ) {
    push @got, $hit->{content};
}
is_deeply( \@got, [ 'a', 'c' .. 'z' ], "correct hits" );

my $frozen = freeze($match_all_query);
my $thawed = thaw($frozen);
ok( $match_all_query->equals($thawed), "equals" );
$thawed->set_boost(10);
ok( !$match_all_query->equals($thawed), '!equals (boost)' );

my $compiler = $match_all_query->make_compiler( searcher => $searcher );
$frozen = freeze($compiler);
$thawed = thaw($frozen);
ok( $thawed->equals($compiler), "freeze/thaw compiler" );

