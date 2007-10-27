use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 8;

use KinoSearch::Search::PhraseQuery;
use KinoSearch::Index::Term;
use KinoSearch::Searcher;

use KinoTestUtils qw( create_invindex );

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
is( $hits->total_hits, 3, "correct number of hits" );
my $first_hit = $hits->fetch_hit_hashref;
is( $first_hit->{content}, $best_match, 'best match appears first' );

my $second_hit = $hits->fetch_hit_hashref;
ok( $first_hit->{score} > $second_hit->{score},
    "best match scores higher: $first_hit->{score} > $second_hit->{score}" );

$phrase_query = KinoSearch::Search::PhraseQuery->new( slop => 0 );
for (qw( c a )) {
    my $term = KinoSearch::Index::Term->new( 'content', $_ );
    $phrase_query->add_term($term);
}
$hits = $searcher->search( query => $phrase_query );
is( $hits->total_hits, 1, 'avoid underflow when subtracting offset' );

# "a b c"
$phrase_query = KinoSearch::Search::PhraseQuery->new( slop => 0 );
$phrase_query->add_term( KinoSearch::Index::Term->new( 'content', 'a' ), 0 );
$phrase_query->add_term( KinoSearch::Index::Term->new( 'content', 'b' ), 1 );
$phrase_query->add_term( KinoSearch::Index::Term->new( 'content', 'c' ), 2 );
$hits = $searcher->search( query => $phrase_query );
is( $hits->total_hits, 3, 'offset starting from zero' );

# "* * a b c"
$phrase_query = KinoSearch::Search::PhraseQuery->new( slop => 0 );
$phrase_query->add_term( KinoSearch::Index::Term->new( 'content', 'a' ), 2 );
$phrase_query->add_term( KinoSearch::Index::Term->new( 'content', 'b' ), 3 );
$phrase_query->add_term( KinoSearch::Index::Term->new( 'content', 'c' ), 4 );
$hits = $searcher->search( query => $phrase_query );
is( $hits->total_hits, 2, 'offset starting from two' );

# "* * * c d"
$phrase_query = KinoSearch::Search::PhraseQuery->new( slop => 0 );
$phrase_query->add_term( KinoSearch::Index::Term->new( 'content', 'c' ), 3 );
$phrase_query->add_term( KinoSearch::Index::Term->new( 'content', 'd' ), 4 );
$hits = $searcher->search( query => $phrase_query );
is( $hits->total_hits, 2, 'offset starting from three' );

# "a * c"
$phrase_query = KinoSearch::Search::PhraseQuery->new( slop => 0 );
$phrase_query->add_term( KinoSearch::Index::Term->new( 'content', 'a' ), 0 );
$phrase_query->add_term( KinoSearch::Index::Term->new( 'content', 'c' ), 2 );
$hits = $searcher->search( query => $phrase_query );
is( $hits->total_hits, 3, 'offsets with gap in middle' );
