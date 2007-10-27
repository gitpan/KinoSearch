use strict;
use warnings;

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
        plan( tests => 6 );
    }
}

package SortSchema::UnAnalyzed;
use base qw( KinoSearch::FieldSpec::text );
sub analyzed {0}

package SortSchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;
sub analyzer { KinoSearch::Analysis::Tokenizer->new }

our %fields = (
    content => 'text',
    number  => 'SortSchema::UnAnalyzed',
);

package main;

use KinoSearch::Search::SearchServer;
use KinoSearch::Search::SearchClient;
use KinoSearch::Searcher;
use KinoSearch::Search::SortSpec;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Search::MultiSearcher;
use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;
use KinoSearch::Store::RAMFolder;

my $kid;
$kid = fork;
if ($kid) {
    sleep .25;    # allow time for the server to set up the socket
    die "Failed fork: $!" unless defined $kid;
}
else {
    my $invindex = KinoSearch::InvIndex->clobber(
        folder => KinoSearch::Store::RAMFolder->new,
        schema => SortSchema->new,
    );
    my $invindexer = KinoSearch::InvIndexer->new(
        invindex => $invindex,
    );
    my $number = 5;
    for (qw( a b c )) {
        $invindexer->add_doc( { content => "x $_", number => $number });
        $number -= 2;
    }
    $invindexer->finish;
    
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
    schema       => SortSchema->new,
    peer_address => 'localhost:7890',
    password     => 'foo',
);

my $hits = $searchclient->search( query => 'x' );
is( $hits->total_hits, 3, "retrieved hits from search server" );

$hits = $searchclient->search( query => 'a' );
is( $hits->total_hits, 1, "retrieved hit from search server" );

my $invindex_b = KinoSearch::InvIndex->clobber(
    folder => KinoSearch::Store::RAMFolder->new,
    schema => SortSchema->new,
);
my $number = 6;
for (qw( a b c )) {
    my $invindexer = KinoSearch::InvIndexer->new(
        invindex => $invindex_b,
    );
    $invindexer->add_doc( { content => "y $_", number => $number });
    $number -= 2;
    $invindexer->add_doc( { content => 'blah blah blah' } ) for 1 .. 3;
    $invindexer->finish;
}

my $searcher_b = KinoSearch::Searcher->new( invindex => $invindex_b, );
is( ref( $searcher_b->get_reader), 'KinoSearch::Index::MultiReader',
    "Prepare to test MultiLex_Seek_By_Num" );

my $multi_searcher = KinoSearch::Search::MultiSearcher->new(
    searchables => [ $searcher_b, $searchclient ], );

$hits = $multi_searcher->search( query => 'b' );
is( $hits->total_hits, 2, "retrieved hits from MultiSearcher" );

my %results;
$results{ $hits->fetch_hit_hashref()->{content} } = 1;
$results{ $hits->fetch_hit_hashref()->{content} } = 1;
my %expected = ( 'x b' => 1, 'y b' => 1, );

is_deeply( \%results, \%expected, "docs fetched from both local and remote" );

KinoSearch::Search::MultiSearcher->set_enable_sorting(1);
my $sort_spec = KinoSearch::Search::SortSpec->new();
$sort_spec->add( field => 'number' );
$hits = $multi_searcher->search(
    query     => 'b',
    sort_spec => $sort_spec,
);
my @got;
while ( my $hit = $hits->fetch_hit_hashref ) {
    push @got, $hit->{content};
}
$sort_spec = KinoSearch::Search::SortSpec->new();
$sort_spec->add( field => 'number', reverse => 1 );
$hits = $multi_searcher->search(
    query     => 'b',
    sort_spec => $sort_spec,
);
my @reversed;
while ( my $hit = $hits->fetch_hit_hashref ) {
    push @reversed, $hit->{content};
}
is_deeply(
    \@got,
    [ reverse @reversed ],
    "Sort combination of remote and local"
);

END {
    $searchclient->terminate if defined $searchclient;
    kill( TERM => $kid ) if $kid;
}
