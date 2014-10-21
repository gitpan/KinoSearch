use strict;
use warnings;
use lib 'buildlib';

use Test::More tests => 7;
use Storable qw( freeze thaw );
use KinoSearch::Test::TestUtils qw( create_index );

my $folder = create_index( 'a', 'b', 'b c', 'c', 'c d', 'd', 'e' );
my $searcher = KinoSearch::Search::IndexSearcher->new( index => $folder );
my $reader = $searcher->get_reader->get_seg_readers->[0];

my $b_query = KinoSearch::Search::TermQuery->new(
    field => 'content',
    term  => 'b'
);
my $c_query = KinoSearch::Search::TermQuery->new(
    field => 'content',
    term  => 'c'
);
my $x_query = KinoSearch::Search::TermQuery->new(
    field => 'content',
    term  => 'x'
);

my $req_opt_query = KinoSearch::Search::RequiredOptionalQuery->new(
    required_query => $b_query,
    optional_query => $c_query,
);
is( $req_opt_query->to_string, "(+content:b content:c)", "to_string" );

my $compiler = $req_opt_query->make_compiler( searcher => $searcher );
my $frozen   = freeze($compiler);
my $thawed   = thaw($frozen);
ok( $thawed->equals($compiler), "freeze/thaw compiler" );
my $matcher = $compiler->make_matcher( reader => $reader, need_score => 1 );
isa_ok( $matcher, 'KinoSearch::Search::RequiredOptionalScorer' );

$req_opt_query = KinoSearch::Search::RequiredOptionalQuery->new(
    required_query => $b_query,
    optional_query => $x_query,
);
$matcher = $req_opt_query->make_compiler( searcher => $searcher )
    ->make_matcher( reader => $reader, need_score => 0 );
isa_ok(
    $matcher,
    'KinoSearch::Search::TermScorer',
    "return required matcher only when opt matcher doesn't match"
);

$req_opt_query = KinoSearch::Search::RequiredOptionalQuery->new(
    required_query => $x_query,
    optional_query => $b_query,
);
$matcher = $req_opt_query->make_compiler( searcher => $searcher )
    ->make_matcher( reader => $reader, need_score => 0 );
ok( !defined($matcher), "if required matcher has no match, return undef" );

$frozen = freeze($req_opt_query);
$thawed = thaw($frozen);
ok( $req_opt_query->equals($thawed), "equals" );
$thawed->set_boost(10);
ok( !$req_opt_query->equals($thawed), '!equals (boost)' );

