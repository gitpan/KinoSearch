#!/usr/bin/perl
use strict;
use warnings;

use lib 't';
use Test::More tests => 4;

BEGIN { use_ok('KinoSearch::Search::Hits') }
use KinoSearch::Searcher;
use KinoSearch::Analysis::Tokenizer;
use KinoSearchTestInvIndex qw( create_invindex );

my @docs     = ( 'a b', 'a a b', 'a a a b', 'x' );
my $invindex = create_invindex(@docs);

my $searcher = KinoSearch::Searcher->new(
    invindex => $invindex,
    analyzer => KinoSearch::Analysis::Tokenizer->new,
);

my $hits = $searcher->search( query => 'a' );
my @ids;
my @retrieved;
while ( my $hit = $hits->fetch_hit ) {
    push @ids, $hit->get_id;
    my $doc = $hit->get_doc;
    push @retrieved, $doc->get_value('content');
}
is_deeply( \@ids, [ 2, 1, 0 ], "get_id()" );
is_deeply(
    \@retrieved,
    [ @docs[ 2, 1, 0 ] ],
    "correct content via fetch_hit() and get_doc()"
);

@retrieved = ();
$hits = $searcher->search( query => 'a' );
while ( my $hashref = $hits->fetch_hit_hashref ) {
    push @retrieved, $hashref->{content};
}
is_deeply(
    \@retrieved,
    [ @docs[ 2, 1, 0 ] ],
    "correct content via fetch_hit_hashref()"
);
