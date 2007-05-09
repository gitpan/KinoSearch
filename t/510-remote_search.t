use strict;
use warnings;
use lib 'buildlib';

use File::Spec::Functions qw( catfile );
use Test::More;
use Time::HiRes qw( sleep );

BEGIN {
    if ( $^O =~ /mswin/i ) {
        plan( 'skip_all', "fork on Windows not supported by KS" );
    }
    elsif ( $ENV{KINO_VALGRIND} ) {
        plan( 'skip_all', "time outs cause probs under valgrind" );
    }
    else {
        plan( tests => 4 );
    }
}

use KinoSearch::Search::SearchServer;
use KinoSearch::Search::SearchClient;
use KinoSearch::Searcher;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Search::MultiSearcher;
use KinoTestUtils qw( create_invindex );

my $kid;
$kid = fork;
if ($kid) {
    sleep .25;    # allow time for the server to set up the socket
    die "Failed fork: $!" unless defined $kid;
}
else {
    my $invindex = create_invindex( 'x a', 'x b', 'x c' );

    my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );

    my $server = KinoSearch::Search::SearchServer->new(
        port       => 7890,
        searchable => $searcher,
        password   => 'foo',
    );

    $server->serve;
    exit(0);
}

my $searchclient = KinoSearch::Search::SearchClient->new(
    schema       => TestSchema->new,
    peer_address => 'localhost:7890',
    password     => 'foo',
);

my $hits = $searchclient->search( query => 'x' );
is( $hits->total_hits, 3, "retrieved hits from search server" );

$hits = $searchclient->search( query => 'a' );
is( $hits->total_hits, 1, "retrieved hit from search server" );

my $invindex_b = create_invindex( 'y b', 'y c', 'y d' );
my $searcher_b = KinoSearch::Searcher->new( invindex => $invindex_b, );

my $multi_searcher = KinoSearch::Search::MultiSearcher->new(
    searchables => [ $searcher_b, $searchclient ], );

$hits = $multi_searcher->search( query => 'b' );
is( $hits->total_hits, 2, "retrieved hits from MultiSearcher" );

my %results;
$results{ $hits->fetch_hit_hashref()->{content} } = 1;
$results{ $hits->fetch_hit_hashref()->{content} } = 1;
my %expected = ( 'x b' => 1, 'y b' => 1, );

is_deeply( \%results, \%expected, "docs fetched from both local and remote" );

END {
    $searchclient->terminate if defined $searchclient;
    kill( TERM => $kid ) if $kid;
}
