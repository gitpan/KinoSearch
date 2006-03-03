#!/usr/bin/perl

use lib 't';
use Test::More tests => 4;
use File::Spec::Functions qw( catfile );

BEGIN { use_ok('KinoSearch::Search::PhraseQuery') }

use KinoSearchTestInvIndex qw( create_invindex );
use KinoSearch::Index::Term;
use KinoSearch::Searcher;

my $best_match = 'x a b c d a b c d';

my @docs = (
    1 .. 20,
    'a b c a b c a b c d',
    'a b c d x x a',
    'a c b d', 'a x x x b x x x c x x x x x x d x',
    $best_match, 'a' .. 'z',
);

my $invindex = create_invindex(@docs);
my $searcher = KinoSearch::Searcher->new( invindex => $invindex );

my $phrase_query = KinoSearch::Search::PhraseQuery->new( slop => 0 );
for (qw( a b c d )) {
    my $term = KinoSearch::Index::Term->new( 'content', $_ );
    $phrase_query->add_term($term);
}

my $hits = $searcher->search( query => $phrase_query );
$hits->seek( 0, 50 );
is( $hits->total_hits, 3, "correct number of hits" );
my $first_hit = $hits->fetch_hit_hashref;
is( $first_hit->{content}, $best_match, 'best match appears first' );

my $second_hit = $hits->fetch_hit_hashref;
ok( $first_hit->{score} > $second_hit->{score},
    "best match scores higher: $first_hit->{score} > $second_hit->{score}" );

