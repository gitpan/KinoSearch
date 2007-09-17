#!/usr/bin/perl
use strict;
use warnings;

use lib 't';
use Test::More tests => 2;

use KinoSearchTestInvIndex qw( create_invindex );

use KinoSearch::Searcher;
use KinoSearch::InvIndexer;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Search::TermQuery;
use KinoSearch::Search::PhraseQuery;
use KinoSearch::Search::BooleanQuery;
use KinoSearch::Index::Term;

my $doc_1 = 'a a a a a a a a a a a a b c d x y';
my $doc_2 = 'a b c d x y x y';

my $invindex = create_invindex( $doc_1, $doc_2 );
my $analyzer = KinoSearch::Analysis::Tokenizer->new( token_re => qr/\S+/ );
my $searcher = KinoSearch::Searcher->new(
    invindex => $invindex,
    analyzer => $analyzer,
);

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
my $first_score = $hit->{score};

$x_y_query->set_boost(20);
$hits = $searcher->search( query => $combined_query );
$hits->seek( 0, 50 );
$hit = $hits->fetch_hit_hashref;
is( $hit->{content}, $doc_2, "boosting a sub query succeeds" );

