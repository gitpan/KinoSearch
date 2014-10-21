use strict;
use warnings;
use lib 'buildlib';

package MyMatcher;
use base qw( KinoSearch::Search::Matcher );

package main;

use Test::More tests => 22;

use KSx::Search::MockScorer;
use KinoSearch::Test;

my $matcher = MyMatcher->new;
for (qw( score get_doc_id next )) {
    eval { $matcher->$_; };
    like( $@, qr/abstract/i, "$_ is abstract" );
}

my $got = test_search( docs => [ 1 .. 10 ] );
is_deeply( $got, [ 1 .. 10 ], "defaults" );

$got = test_search( docs => [ 1 .. 3, 5 .. 10 ], dels => [4] );
is_deeply( $got, [ 1 .. 3, 5 .. 10 ], "deletion between hits" );

$got = test_search( docs => [ 1 .. 3, 5 .. 10 ], dels => [5] );
is_deeply( $got, [ 1 .. 3, 6 .. 10 ], "deletion after gap" );

$got = test_search( docs => [ 1 .. 3, 5 .. 10 ], dels => [1] );
is_deeply( $got, [ 2 .. 3, 5 .. 10 ], "first doc deleted" );

$got = test_search( docs => [ 1 .. 3, 5 .. 10 ], dels => [ 1, 2 ] );
is_deeply( $got, [ 3, 5 .. 10 ], "first two docs deleted" );

$got = test_search( docs => [ 1 .. 3, 5 .. 10 ], dels => [10] );
is_deeply( $got, [ 1 .. 3, 5 .. 9 ], "last doc deleted" );

$got = test_search( docs => [ 1 .. 3, 5 .. 10 ], dels => [ 9, 10 ] );
is_deeply( $got, [ 1 .. 3, 5 .. 8 ], "last two docs deleted" );

$got = test_search( docs => [ 1 .. 3, 5 .. 10 ], dels => [ 3, 4 ] );
is_deeply( $got, [ 1 .. 2, 5 .. 10 ], "deletions continuing into gap" );

$got = test_search( docs => [ 1 .. 3, 5 .. 10 ], dels => [ 4, 5 ] );
is_deeply( $got, [ 1 .. 3, 6 .. 10 ], "deletions continuing from gap" );

$got = test_search( docs => [ 1 .. 3, 5 .. 10 ], dels => [ 3, 4, 5 ] );
is_deeply( $got, [ 1 .. 2, 6 .. 10 ], "deletions spanning gap" );

$got = test_search( docs => [ 1 .. 3, 5 .. 10 ], dels => [ 3, 5 ] );
is_deeply( $got, [ 1 .. 2, 6 .. 10 ], "deletions surrounding gap" );

$got = test_search( docs => [ 1 .. 3, 5, 7 .. 10 ], dels => [5] );
is_deeply( $got, [ 1 .. 3, 7 .. 10 ], "gaps surrounding deletion" );

$got = test_search( docs => [ 1, 3, 5, 7, 9 ], dels => [ 2, 4, 6, 8, 10 ] );
is_deeply( $got, [ 1, 3, 5, 7, 9 ], "synchronized gaps and deletions" );

$got = test_search( docs => [ 1, 3, 5, 7, 9 ], dels => [ 1, 3, 5, 7, 9 ] );
is_deeply( $got, [], "alternating gaps and deletions" );

$got = test_search( docs => [ 1 .. 3, 6 .. 10 ], dels => [ 4, 5 ] );
is_deeply( $got, [ 1 .. 3, 6 .. 10 ], "two deletions between hits" );

$got = test_search( docs => [ 1 .. 3, 6 .. 10 ], dels => [3] );
is_deeply( $got, [ 1 .. 2, 6 .. 10 ], "deletion before double gap" );

$got = test_search( docs => [ 1 .. 3, 6 .. 10 ], dels => [6] );
is_deeply( $got, [ 1 .. 3, 7 .. 10 ], "deletion after double gap" );

$got = test_search( docs => [ 1 .. 3, 6 .. 10 ], dels => [ 3, 4, 5 ] );
is_deeply( $got, [ 1 .. 2, 6 .. 10 ],
    "deletions continuing into double gap" );

$got = test_search( docs => [ 1 .. 3, 6 .. 10 ], dels => [ 4, 5, 6 ] );
is_deeply(
    $got,
    [ 1 .. 3, 7 .. 10 ],
    "deletions continuing out of double gap"
);

sub test_search {
    my %args = @_;
    my $docs = delete $args{docs} || [];
    my $dels = delete $args{dels} || [];
    my $del_enum;

    my $matcher = KSx::Search::MockScorer->new(
        doc_ids => $docs,
        scores  => [ (0) x scalar @$docs ],
    );
    if (@$dels) {
        my $bit_vec = KinoSearch::Object::BitVector->new(
            capacity => $dels->[-1] + 1 );
        $bit_vec->set($_) for @$dels;
        $del_enum = KinoSearch::Search::BitVecMatcher->new(
            bit_vector => $bit_vec );
    }

    my $collector
        = KinoSearch::Search::Collector::SortCollector->new( wanted => 100 );
    $matcher->collect(
        %KinoSearch::Search::Matcher::collect_PARAMS,
        collector => $collector,
        deletions => $del_enum,
        %args,
    );
    my $match_docs = $collector->pop_match_docs;
    my @doc_ids = map { $_->get_doc_id } @$match_docs;
    return \@doc_ids;
}
