use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 12;
use Storable qw( freeze thaw );
use KinoSearch::Test;
use KinoSearch::Test::TestUtils qw( create_index );

my $folder = create_index( 'a', 'b', 'c c c d', 'c d', 'd' .. 'z', );
my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );

my $term_query
    = KinoSearch::Search::TermQuery->new( field => 'content', term => 'c' );
is( $term_query->to_string, "content:c", "to_string" );

my $hits = $searcher->hits( query => $term_query );
is( $hits->total_hits, 2, "correct number of hits returned" );

my $hit = $hits->next;
is( $hit->{content}, 'c c c d', "most relevant doc is highest" );

$hit = $hits->next;
is( $hit->{content}, 'c d', "second most relevant" );

my $frozen = freeze($term_query);
my $thawed = thaw($frozen);
is( $thawed->get_field, 'content', "field survives freeze/thaw" );
is( $thawed->get_term,  'c',       "term survives freeze/thaw" );
is( $thawed->get_boost, $term_query->get_boost,
    "boost survives freeze/thaw" );
ok( $thawed->equals($term_query), "equals" );
$thawed->set_boost(10);
ok( !$thawed->equals($term_query), "!equals (boost)" );
my $different_term = KinoSearch::Search::TermQuery->new(
    field => 'content',
    term  => 'd'
);
my $different_field = KinoSearch::Search::TermQuery->new(
    field => 'title',
    term  => 'c'
);
ok( !$term_query->equals($different_term),  "!equals (term)" );
ok( !$term_query->equals($different_field), "!equals (field)" );

my $term_compiler = $term_query->make_compiler( searcher => $searcher );
$frozen = freeze($term_compiler);
$thawed = thaw($frozen);
ok( $term_compiler->equals($thawed), "freeze/thaw compiler" );
