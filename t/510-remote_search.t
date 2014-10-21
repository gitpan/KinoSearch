use strict;
use warnings;

use Test::More;
use Time::HiRes qw( sleep );
use IO::Socket::INET;

my $PORT_NUM = 7890;
BEGIN {
    if ( $^O =~ /mswin/i ) {
        plan( 'skip_all', "fork on Windows not supported by KS" );
    }
    elsif ( $ENV{KINO_VALGRIND} ) {
        plan( 'skip_all', "time outs cause probs under valgrind" );
    }
}

package SortSchema;
use base qw( KinoSearch::Plan::Schema );
use KinoSearch::Analysis::Tokenizer;

sub new {
    my $self       = shift->SUPER::new(@_);
    my $plain_type = KinoSearch::Plan::FullTextType->new(
        analyzer => KinoSearch::Analysis::Tokenizer->new );
    my $string_type = KinoSearch::Plan::StringType->new( sortable => 1 );
    $self->spec_field( name => 'content', type => $plain_type );
    $self->spec_field( name => 'number',  type => $string_type );
    return $self;
}

package main;

use KinoSearch::Test;
use KSx::Remote::SearchServer;
use KSx::Remote::SearchClient;

my $kid;
$kid = fork;
if ($kid) {
    sleep .25;    # allow time for the server to set up the socket
    die "Failed fork: $!" unless defined $kid;
}
else {
    my $folder  = KinoSearch::Store::RAMFolder->new;
    my $indexer = KinoSearch::Index::Indexer->new(
        index  => $folder,
        schema => SortSchema->new,
    );
    my $number = 5;
    for (qw( a b c )) {
        $indexer->add_doc( { content => "x $_", number => $number } );
        $number -= 2;
    }
    $indexer->commit;

    my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );
    my $server = KSx::Remote::SearchServer->new(
        port     => $PORT_NUM,
        searcher => $searcher,
        password => 'foo',
    );
    $server->serve;
    exit(0);
}

my $test_client_sock = IO::Socket::INET->new(
    PeerAddr => "localhost:$PORT_NUM",
    Proto    => 'tcp',
);
if ($test_client_sock) {
    plan( tests => 10 );
    undef $test_client_sock;
}
else {
    plan( 'skip_all', "Can't get a socket: $!" );
}

my $searchclient = KSx::Remote::SearchClient->new(
    schema       => SortSchema->new,
    peer_address => "localhost:$PORT_NUM",
    password     => 'foo',
);

is( $searchclient->doc_freq( field => 'content', term => 'x' ),
    3, "doc_freq" );
is( $searchclient->doc_max, 3, "doc_max" );
isa_ok( $searchclient->fetch_doc( doc_id => 1 ),
    "KinoSearch::Document::HitDoc", "fetch_doc" );
isa_ok(
    $searchclient->fetch_doc_vec(1),
    "KinoSearch::Index::DocVector",
    "fetch_doc_vec"
);

my $hits = $searchclient->hits( query => 'x' );
is( $hits->total_hits, 3, "retrieved hits from search server" );

$hits = $searchclient->hits( query => 'a' );
is( $hits->total_hits, 1, "retrieved hit from search server" );

my $folder_b = KinoSearch::Store::RAMFolder->new;
my $number   = 6;
for (qw( a b c )) {
    my $indexer = KinoSearch::Index::Indexer->new(
        index  => $folder_b,
        schema => SortSchema->new,
    );
    $indexer->add_doc( { content => "y $_", number => $number } );
    $number -= 2;
    $indexer->add_doc( { content => 'blah blah blah' } ) for 1 .. 3;
    $indexer->commit;
}

my $searcher_b
    = KinoSearch::Search::IndexSearcher->new( index => $folder_b, );
is( ref( $searcher_b->get_reader ), 'KinoSearch::Index::PolyReader', );

my $poly_searcher = KinoSearch::Search::PolySearcher->new(
    schema    => SortSchema->new,
    searchers => [ $searcher_b, $searchclient ],
);

$hits = $poly_searcher->hits( query => 'b' );
is( $hits->total_hits, 2, "retrieved hits from PolySearcher" );

my %results;
$results{ $hits->next()->{content} } = 1;
$results{ $hits->next()->{content} } = 1;
my %expected = ( 'x b' => 1, 'y b' => 1, );

is_deeply( \%results, \%expected, "docs fetched from both local and remote" );

my $sort_spec = KinoSearch::Search::SortSpec->new(
    rules => [
        KinoSearch::Search::SortRule->new( field => 'number' ),
        KinoSearch::Search::SortRule->new( type  => 'doc_id' ),
    ],
);
$hits = $poly_searcher->hits(
    query     => 'b',
    sort_spec => $sort_spec,
);
my @got;

while ( my $hit = $hits->next ) {
    push @got, $hit->{content};
}
$sort_spec = KinoSearch::Search::SortSpec->new(
    rules => [
        KinoSearch::Search::SortRule->new( field => 'number', reverse => 1 ),
        KinoSearch::Search::SortRule->new( type  => 'doc_id' ),
    ],
);
$hits = $poly_searcher->hits(
    query     => 'b',
    sort_spec => $sort_spec,
);
my @reversed;
while ( my $hit = $hits->next ) {
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
