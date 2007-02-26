use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 8;

BEGIN { use_ok('KinoSearch::Search::Hits') }
use KinoSearch::Searcher;
use KinoTestUtils qw( create_invindex );

my @docs     = ( 'a b', 'a a b', 'a a a b', 'x' );
my $invindex = create_invindex(@docs);

my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );

my $hits = $searcher->search(
    query      => 'a',
    offset     => 0,
    num_wanted => 1,
);
is( $hits->total_hits, 3, "total_hits" );
my $hit = $hits->fetch_hit_hashref;
cmp_ok( $hit->{score}, '>', 0.0, "score field added" );
is( $hits->fetch_hit_hashref, undef, "hits exhausted" );

$hits->seek( 0, 1 );
is_deeply( $hits->fetch_hit_hashref, $hit, "seek back to top" );
is( $hits->fetch_hit_hashref, undef, "hits exhausted" );

my @retrieved;
@retrieved = ();
$hits->seek( 0, 100 );
is( $hits->total_hits, 3, "total_hits still correct" );
while ( my $hashref = $hits->fetch_hit_hashref ) {
    push @retrieved, $hashref->{content};
}
is_deeply(
    \@retrieved,
    [ @docs[ 2, 1, 0 ] ],
    "correct content via fetch_hit_hashref()"
);
