use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 4;
use File::Spec::Functions qw( catfile );

use KinoSearch::Search::TermQuery;
use KinoSearch::Index::Term;
use KinoSearch::Searcher;

use KinoTestUtils qw( create_invindex );

my $invindex = create_invindex( 'a', 'b', 'c c c d', 'c d', 'd' .. 'z', );

my $term = KinoSearch::Index::Term->new( 'content', 'c' );
my $term_query = KinoSearch::Search::TermQuery->new( term => $term );
my $searcher   = KinoSearch::Searcher->new( invindex      => $invindex );

my $hits = $searcher->search( query => $term_query );
is( $hits->total_hits, 2, "correct number of hits returned" );

my $hashref = $hits->fetch_hit_hashref;
is( $hashref->{content}, 'c c c d', "most relevant doc is highest" );

$hashref = $hits->fetch_hit_hashref;
is( $hashref->{content}, 'c d', "second most relevant" );

$hits->seek( 1, 50 );
$hashref = $hits->fetch_hit_hashref;
is( $hashref->{content}, 'c d', "fresh seek" );
