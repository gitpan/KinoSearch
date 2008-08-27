#!/usr/bin/perl

use lib 't';
use Test::More tests => 7;

BEGIN {
    use_ok('KinoSearch::Search::TermQuery');
    use_ok('KinoSearch::Index::Term');
    use_ok('KinoSearch::Searcher');
}

use KinoSearchTestInvIndex qw( create_invindex );

my $invindex = create_invindex( 'a', 'b', 'c c c d', 'c d', 'd' .. 'z', );

my $term = KinoSearch::Index::Term->new( 'content', 'c' );
my $term_query = KinoSearch::Search::TermQuery->new( term => $term );
my $searcher   = KinoSearch::Searcher->new( invindex      => $invindex );

my $hits = $searcher->search( query => $term_query );
$hits->seek( 0, 50 );
is( $hits->total_hits, 2, "correct number of hits returned" );

my $hashref = $hits->fetch_hit_hashref;
is( $hashref->{content}, 'c c c d', "most relevant doc is highest" );

$hashref = $hits->fetch_hit_hashref;
is( $hashref->{content}, 'c d', "second most relevant" );

$hits->seek( 1, 50 );
$hashref = $hits->fetch_hit_hashref;
is( $hashref->{content}, 'c d', "fresh seek" );

