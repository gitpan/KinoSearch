#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 4;
use lib 't';

BEGIN { use_ok('KinoSearch::Search::MultiSearcher') }

use KinoSearch::Searcher;
use KinoSearch::Analysis::Tokenizer;

use KinoSearchTestInvIndex qw( create_invindex );
my $invindex_a = create_invindex( 'x a', 'x b', 'x c' );
my $invindex_b = create_invindex( 'y b', 'y c', 'y d' );

my $tokenizer = KinoSearch::Analysis::Tokenizer->new;

my $searcher_a = KinoSearch::Searcher->new(
    analyzer => $tokenizer,
    invindex => $invindex_a,
);
my $searcher_b = KinoSearch::Searcher->new(
    analyzer => $tokenizer,
    invindex => $invindex_b,
);

my $multi_searcher = KinoSearch::Search::MultiSearcher->new(
    searchables => [ $searcher_a, $searcher_b ], 
    analyzer    => $tokenizer,
);

my $hits = $multi_searcher->search('a');
is( $hits->total_hits, 1, "Find hit in first searcher" );

$hits = $multi_searcher->search('d');
is( $hits->total_hits, 1, "Find hit in second searcher" );

$hits = $multi_searcher->search('c');
is( $hits->total_hits, 2, "Find hits in both searchers" );

