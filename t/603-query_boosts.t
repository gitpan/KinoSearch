use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 2;

use KinoTestUtils qw( create_invindex );

use KinoSearch::Searcher;
use KinoSearch::InvIndexer;
use KinoSearch::Search::TermQuery;
use KinoSearch::Search::PhraseQuery;
use KinoSearch::Search::BooleanQuery;
use KinoSearch::Index::Term;

my $doc_1
    = 'a a a a a a a a a a a a a a a a a a a b c d x y ' . ( 'z ' x 100 );
my $doc_2 = 'a b c d x y x y ' . ( 'z ' x 100 );

my $invindex = create_invindex( $doc_1, $doc_2 );
my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );

my $a_query = KinoSearch::Search::TermQuery->new(
    term => KinoSearch::Index::Term->new( 'content', 'a' ) );
my $x_y_query = KinoSearch::Search::PhraseQuery->new;
$x_y_query->add_term( KinoSearch::Index::Term->new( 'content', 'x' ) );
$x_y_query->add_term( KinoSearch::Index::Term->new( 'content', 'y' ) );

my $combined_query = KinoSearch::Search::BooleanQuery->new;
$combined_query->add_clause( query => $a_query,   occur => 'SHOULD' );
$combined_query->add_clause( query => $x_y_query, occur => 'SHOULD' );
my $hits = $searcher->search( query => $combined_query );
$hits->seek( 0, 50 );
my $hit = $hits->fetch_hit_hashref;
is( $hit->{content}, $doc_1, "best doc ranks highest with no boosting" );

$x_y_query->set_boost(2);
$hits = $searcher->search( query => $combined_query );
$hits->seek( 0, 50 );
$hit = $hits->fetch_hit_hashref;
is( $hit->{content}, $doc_2, "boosting a sub query succeeds" );
